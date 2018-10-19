## sanlock守护进程初始化

1. 守护进程主函数执行初始化。

- src/main.c

```
int main(int argc, char *argv[])
{
...
	switch (com.type) {
	case COM_DAEMON:
		rv = do_daemon();
		break;

	case COM_CLIENT:
		rv = do_client();
		break;

	case COM_DIRECT:
		rv = do_direct();
		break;
	};
...
}

static int do_daemon(void)
{
	int fd, rv;


	/* This can take a while so do it before forking. */
	setup_groups();

	if (!com.debug) {
		/* TODO: copy comprehensive daemonization method from libvirtd */
		if (daemon(0, 0) < 0) {
			log_tool("cannot fork daemon\n");
			exit(EXIT_FAILURE);
		}
	}

	setup_limits();
	setup_helper();

	/* main task never does disk io, so we don't really need to set
	 * it up, but other tasks get their use_aio value by copying
	 * the main_task settings */

	sprintf(main_task.name, "%s", "main");
	setup_task_aio(&main_task, com.aio_arg, 0);

	rv = client_alloc();
	if (rv < 0)
		return rv;

	helper_ci = client_add(helper_status_fd, process_helper, helper_dead);
	if (helper_ci < 0)
		return rv;
	strcpy(client[helper_ci].owner_name, "helper");

	setup_signals();
	setup_logging();

	fd = lockfile(SANLK_RUN_DIR, SANLK_LOCKFILE_NAME, com.uid, com.gid);
	if (fd < 0) {
		close_logging();
		return fd;
	}

	setup_host_name();

	setup_uid_gid();

	log_level(0, 0, NULL, LOG_WARNING, "sanlock daemon started %s host %s",
		  VERSION, our_host_name_global);

	setup_priority();

	rv = thread_pool_create(DEFAULT_MIN_WORKER_THREADS, com.max_worker_threads);
	if (rv < 0)
		goto out;

	rv = setup_listener();
	if (rv < 0)
		goto out_threads;

	setup_token_manager();
	if (rv < 0)
		goto out_threads;

	/* initialize global eventfd for client_resume notification */
	if ((efd = eventfd(0, EFD_CLOEXEC | EFD_NONBLOCK)) == -1) {
		log_error("couldn't create eventfd");
		goto out_threads;
	}

	main_loop();

	close_token_manager();

 out_threads:
	thread_pool_free();
 out:
	/* order reversed from setup so lockfile is last */
	close_logging();
	unlink_lockfile(fd, SANLK_RUN_DIR, SANLK_LOCKFILE_NAME);
	return rv;
}
```

2. 创建helper子进程负责执行kill信号或者执行killpath指定的程序。

- src/main.c

```
/*
 * first pipe for daemon to send requests to helper; they are not acknowledged
 * and the daemon does not get any result back for the requests.
 *
 * second pipe for helper to send general status/heartbeat back to the daemon
 * every so often to confirm it's not dead/hung.  If the helper gets stuck or
 * killed, the daemon will not get the status and won't bother sending requests
 * to the helper, and use SIGTERM instead
 */

static int setup_helper(void)
{
	int pid;
	int pw_fd = -1; /* parent write */
	int cr_fd = -1; /* child read */
	int pr_fd = -1; /* parent read */
	int cw_fd = -1; /* child write */
	int pfd[2];

	/* we can't allow the main daemon thread to block */
	if (pipe2(pfd, O_NONBLOCK | O_CLOEXEC))
		return -errno;

	/* uncomment for rhel7 where this should be available */
	/* fcntl(pfd[1], F_SETPIPE_SZ, 1024*1024); */

	cr_fd = pfd[0];
	pw_fd = pfd[1];

	if (pipe2(pfd, O_NONBLOCK | O_CLOEXEC)) {
		close(cr_fd);
		close(pw_fd);
		return -errno;
	}

	pr_fd = pfd[0];
	cw_fd = pfd[1];

	pid = fork();
	if (pid < 0) {
		close(cr_fd);
		close(pw_fd);
		close(pr_fd);
		close(cw_fd);
		return -errno;
	}

	if (pid) {
		close(cr_fd);
		close(cw_fd);
		helper_kill_fd = pw_fd;
		helper_status_fd = pr_fd;
		helper_pid = pid;
		return 0;
	} else {
		close(pr_fd);
		close(pw_fd);
		run_helper(cr_fd, cw_fd, (log_stderr_priority == LOG_DEBUG));
		exit(0);
	}
}

```

- src/helper.c

通过和主进程之间的管道读取命令并执行：

```
int run_helper(int in_fd, int out_fd, int log_stderr)
{
	char name[16];
	struct pollfd pollfd;
	struct helper_msg hm;
	unsigned int fork_count = 0;
	unsigned int wait_count = 0;
	time_t now, last_send, last_good = 0;
	int timeout = STANDARD_TIMEOUT_MS;
	int rv, pid, status;

	memset(name, 0, sizeof(name));
	sprintf(name, "%s", "sanlock-helper");
	prctl(PR_SET_NAME, (unsigned long)name, 0, 0, 0);

	rv = setgroups(0, NULL);
	if (rv < 0)
		log_debug("error clearing helper groups errno %i", errno);

	memset(&pollfd, 0, sizeof(pollfd));
	pollfd.fd = in_fd;
	pollfd.events = POLLIN;

	now = monotime();
	last_send = now;
	rv = send_status(out_fd);
	if (!rv)
		last_good = now;

	while (1) {
		rv = poll(&pollfd, 1, timeout);
		if (rv == -1 && errno == EINTR)
			continue;

		if (rv < 0)
			exit(0);

		now = monotime();

		if (now - last_good >= HELPER_STATUS_INTERVAL &&
		    now - last_send >= 2) {
			last_send = now;
			rv = send_status(out_fd);
			if (!rv)
				last_good = now;
		}

		memset(&hm, 0, sizeof(hm));

		if (pollfd.revents & POLLIN) {
			rv = read_hm(in_fd, &hm);
			if (rv)
				continue;

			if (hm.type == HELPER_MSG_RUNPATH) {
				pid = fork();
				if (!pid) {
					run_path(&hm);
					exit(-1);
				}

				fork_count++;

				/*
				log_debug("helper fork %d count %d %d %s %s",
					  pid, fork_count, wait_count,
					  hm.path, hm.args);
				*/
			} else if (hm.type == HELPER_MSG_KILLPID) {
				kill(hm.pid, hm.sig);
			}
		}

		if (pollfd.revents & (POLLERR | POLLHUP | POLLNVAL))
			exit(0);

		/* collect child exits until no more children exist (ECHILD)
		   or none are ready (WNOHANG) */

		while (1) {
			rv = waitpid(-1, &status, WNOHANG);
			if (rv > 0) {
				wait_count++;

				/*
				log_debug("helper wait %d count %d %d",
					  rv, fork_count, wait_count);
				*/
				continue;
			}

			/* no more children to wait for or no children
			   have exited */

			if (rv < 0 && errno == ECHILD) {
				if (timeout == RECOVERY_TIMEOUT_MS) {
					log_debug("helper no children count %d %d",
						  fork_count, wait_count);
				}
				timeout = STANDARD_TIMEOUT_MS;
			} else {
				timeout = RECOVERY_TIMEOUT_MS;
			}
			break;
		}
	}

	return 0;
}

static void run_path(struct helper_msg *hm)
{
	char arg[SANLK_HELPER_ARGS_LEN];
	char *args = hm->args;
	char *av[MAX_AV_COUNT + 1]; /* +1 for NULL */
	int av_count = 0;
	int i, arg_len, args_len;

	for (i = 0; i < MAX_AV_COUNT + 1; i++)
		av[i] = NULL;

	av[av_count++] = strdup(hm->path);

	if (!args[0])
		goto pid_arg;

	/* this should already be done, but make sure */
	args[SANLK_HELPER_ARGS_LEN - 1] = '\0';

	memset(&arg, 0, sizeof(arg));
	arg_len = 0;
	args_len = strlen(args);

	for (i = 0; i < args_len; i++) {
		if (!args[i])
			break;

		if (av_count == MAX_AV_COUNT)
			break;

		if (args[i] == '\\') {
			if (i == (args_len - 1))
				break;
			i++;

			if (args[i] == '\\') {
				arg[arg_len++] = args[i];
				continue;
			}
			if (isspace(args[i])) {
				arg[arg_len++] = args[i];
				continue;
			} else {
				break;
			}
		}

		if (isalnum(args[i]) || ispunct(args[i])) {
			arg[arg_len++] = args[i];
		} else if (isspace(args[i])) {
			if (arg_len)
				av[av_count++] = strdup(arg);

			memset(arg, 0, sizeof(arg));
			arg_len = 0;
		} else {
			break;
		}
	}

	if ((av_count < MAX_AV_COUNT) && arg_len) {
		av[av_count++] = strdup(arg);
	}

 pid_arg:
	if ((av_count < MAX_AV_COUNT) && hm->pid) {
		memset(arg, 0, sizeof(arg));
		snprintf(arg, sizeof(arg)-1, "%d", hm->pid);
		av[av_count++] = strdup(arg);
	}

	execvp(av[0], av);
}

```

3. 初始化并分配客户端管理数据结构。

- src/main.c

```
/* FIXME: add a mutex for client array so we don't try to expand it
   while a cmd thread is using it.  Or, with a thread pool we know
   when cmd threads are running and can expand when none are. */

static int client_alloc(void)
{
	int i;

	/* pollfd is one element longer as we use an additional element for the
	 * eventfd notification mechanism */
	client = malloc(CLIENT_NALLOC * sizeof(struct client));
	pollfd = malloc((CLIENT_NALLOC+1) * sizeof(struct pollfd));

	if (!client || !pollfd) {
		log_error("can't alloc for client or pollfd array");
		return -ENOMEM;
	}

	for (i = 0; i < CLIENT_NALLOC; i++) {
		memset(&client[i], 0, sizeof(struct client));
		memset(&pollfd[i], 0, sizeof(struct pollfd));

		pthread_mutex_init(&client[i].mutex, NULL);
		client[i].fd = -1;
		client[i].pid = -1;

		pollfd[i].fd = -1;
		pollfd[i].events = 0;
	}
	client_size = CLIENT_NALLOC;
	return 0;
}

```

4. 设置本地套接字监听端口及处理函数。

- src/main.c

初始化套接字，并绑定端口，设置处理函数：

```
static int setup_listener(void)
{
	struct sockaddr_un addr;
	int rv, fd, ci;

	rv = sanlock_socket_address(&addr);
	if (rv < 0)
		return rv;

	fd = socket(AF_LOCAL, SOCK_STREAM, 0);
	if (fd < 0)
		return fd;

	unlink(addr.sun_path);
	rv = bind(fd, (struct sockaddr *) &addr, sizeof(struct sockaddr_un));
	if (rv < 0)
		goto exit_fail;

	rv = chmod(addr.sun_path, DEFAULT_SOCKET_MODE);
	if (rv < 0)
		goto exit_fail;

	rv = chown(addr.sun_path, com.uid, com.gid);
	if (rv < 0) {
		log_error("could not set socket %s permissions: %s",
			addr.sun_path, strerror(errno));
		goto exit_fail;
	}

	rv = listen(fd, 5);
	if (rv < 0)
		goto exit_fail;

	fcntl(fd, F_SETFL, fcntl(fd, F_GETFL, 0) | O_NONBLOCK);

	ci = client_add(fd, process_listener, NULL);
	if (ci < 0)
		goto exit_fail;

	strcpy(client[ci].owner_name, "listener");
	return 0;

 exit_fail:
	close(fd);
	return -1;
}

```

- src/sanlock_sock.c

初始化监听地址：

```
int sanlock_socket_address(struct sockaddr_un *addr)
{
	memset(addr, 0, sizeof(struct sockaddr_un));
	addr->sun_family = AF_LOCAL;
	snprintf(addr->sun_path, sizeof(addr->sun_path) - 1, "%s/%s",
		 SANLK_RUN_DIR, SANLK_SOCKET_NAME);
	return 0;
}

```

- src/sanlock_sock.h

默认的本地监听套接字：

```
#define SANLK_RUN_DIR "/var/run/sanlock"
#define SANLK_SOCKET_NAME "sanlock.sock"

```

- src/main.c

服务端处理函数，对于监听套接字，每接收一个新的连接则分配一个client结构与之对应，在SM_CMD_KILLPATH命令中处理设置killpath的功能：

```
static void process_listener(int ci GNUC_UNUSED)
{
	int fd;
	int on = 1;

	fd = accept(client[ci].fd, NULL, NULL);
	if (fd < 0)
		return;

	setsockopt(fd, SOL_SOCKET, SO_PASSCRED, &on, sizeof(on));

	client_add(fd, process_connection, NULL);
}

static void process_connection(int ci)
{
	struct sm_header h;
	void (*deadfn)(int ci);
	int rv;

	memset(&h, 0, sizeof(h));

	rv = recv(client[ci].fd, &h, sizeof(h), MSG_WAITALL);
	if (!rv)
		return;
	if (rv < 0) {
		log_error("ci %d fd %d pid %d recv errno %d",
			  ci, client[ci].fd, client[ci].pid, errno);
		goto dead;
	}
	if (rv != sizeof(h)) {
		log_error("ci %d fd %d pid %d recv size %d",
			  ci, client[ci].fd, client[ci].pid, rv);
		goto dead;
	}
	if (h.magic != SM_MAGIC) {
		log_error("ci %d recv %d magic %x vs %x",
			  ci, rv, h.magic, SM_MAGIC);
		goto dead;
	}
	if (client[ci].restricted & SANLK_RESTRICT_ALL) {
		log_error("ci %d fd %d pid %d cmd %d restrict all",
			  ci, client[ci].fd, client[ci].pid, h.cmd);
		goto dead;
	}
	if (h.version && (h.cmd != SM_CMD_VERSION) &&
	    (h.version & 0xFFFF0000) > (SM_PROTO & 0xFFFF0000)) {
		log_error("ci %d recv %d proto %x vs %x",
			  ci, rv, h.version , SM_PROTO);
		goto dead;
	}

	client[ci].cmd_last = h.cmd;

	switch (h.cmd) {
	case SM_CMD_REGISTER:
	case SM_CMD_RESTRICT:
	case SM_CMD_VERSION:
	case SM_CMD_SHUTDOWN:
	case SM_CMD_STATUS:
	case SM_CMD_HOST_STATUS:
	case SM_CMD_RENEWAL:
	case SM_CMD_LOG_DUMP:
	case SM_CMD_GET_LOCKSPACES:
	case SM_CMD_GET_HOSTS:
	case SM_CMD_REG_EVENT:
	case SM_CMD_END_EVENT:
	case SM_CMD_SET_CONFIG:
		call_cmd_daemon(ci, &h, client_maxi);
		break;
	case SM_CMD_ADD_LOCKSPACE:
	case SM_CMD_INQ_LOCKSPACE:
	case SM_CMD_REM_LOCKSPACE:
	case SM_CMD_REQUEST:
	case SM_CMD_EXAMINE_RESOURCE:
	case SM_CMD_EXAMINE_LOCKSPACE:
	case SM_CMD_ALIGN:
	case SM_CMD_WRITE_LOCKSPACE:
	case SM_CMD_WRITE_RESOURCE:
	case SM_CMD_READ_LOCKSPACE:
	case SM_CMD_READ_RESOURCE:
	case SM_CMD_READ_RESOURCE_OWNERS:
	case SM_CMD_SET_LVB:
	case SM_CMD_GET_LVB:
	case SM_CMD_SHUTDOWN_WAIT:
	case SM_CMD_SET_EVENT:
		rv = client_suspend(ci);
		if (rv < 0)
			return;
		process_cmd_thread_unregistered(ci, &h);
		break;
	case SM_CMD_ACQUIRE:
	case SM_CMD_RELEASE:
	case SM_CMD_INQUIRE:
	case SM_CMD_CONVERT:
	case SM_CMD_KILLPATH:
		/* the main_loop needs to ignore this connection
		   while the thread is working on it */
		rv = client_suspend(ci);
		if (rv < 0)
			return;
		process_cmd_thread_registered(ci, &h);
		break;
	default:
		log_error("ci %d cmd %d unknown", ci, h.cmd);
	};

	return;

 dead:
	deadfn = client[ci].deadfn;
	if (deadfn)
		deadfn(ci);
}

```

**最后进入主循环-main_loop函数中**

## 守护进程主循环

- src/main.c

1. 循环poll每个套接字，如果有数据则执行相应的work函数，也就是之前设置好的process_connection函数。

```
static int main_loop(void)
{
	void (*workfn) (int ci);
	void (*deadfn) (int ci);
	struct space *sp, *safe;
	struct timeval now, last_check;
	int poll_timeout, check_interval;
	unsigned int ms;
	int i, rv, empty, check_all;
	char *check_buf = NULL;
	int check_buf_len = 0;
	uint64_t ebuf;

	gettimeofday(&last_check, NULL);
	poll_timeout = STANDARD_CHECK_INTERVAL;
	check_interval = STANDARD_CHECK_INTERVAL;

	while (1) {
		/* as well as the clients, check the eventfd */
		pollfd[client_maxi+1].fd = efd;
		pollfd[client_maxi+1].events = POLLIN;

		rv = poll(pollfd, client_maxi + 2, poll_timeout);
		if (rv == -1 && errno == EINTR)
			continue;
		if (rv < 0) {
			/* not sure */
		}
		for (i = 0; i <= client_maxi + 1; i++) {
			if (pollfd[i].fd == efd && pollfd[i].revents & POLLIN) {
				/* a client_resume completed */
				eventfd_read(efd, &ebuf);
				continue;
			}
			if (client[i].fd < 0)
				continue;
			if (pollfd[i].revents & POLLIN) {
				workfn = client[i].workfn;
				if (workfn)
					workfn(i);
			}
			if (pollfd[i].revents & (POLLERR | POLLHUP | POLLNVAL)) {
				deadfn = client[i].deadfn;
				if (deadfn)
					deadfn(i);
			}
		}


		gettimeofday(&now, NULL);
		ms = time_diff(&last_check, &now);
		if (ms < check_interval) {
			poll_timeout = check_interval - ms;
			continue;
		}
		last_check = now;
		check_interval = STANDARD_CHECK_INTERVAL;

		/*
		 * check the condition of each lockspace,
		 * if pids are being killed, have pids all exited?
		 * is its host_id being renewed?, if not kill pids
		 */

		pthread_mutex_lock(&spaces_mutex);
		list_for_each_entry_safe(sp, safe, &spaces, list) {

			if (sp->killing_pids && all_pids_dead(sp)) {
				/*
				 * move sp to spaces_rem so main_loop
				 * will no longer see it.
				 */
				log_space(sp, "set thread_stop");
				pthread_mutex_lock(&sp->mutex);
				sp->thread_stop = 1;
				deactivate_watchdog(sp);
				pthread_mutex_unlock(&sp->mutex);
				list_move(&sp->list, &spaces_rem);
				continue;
			}

			if (sp->killing_pids) {
				/*
				 * continue to kill the pids with increasing
				 * levels of severity until they all exit
				 */
				kill_pids(sp);
				check_interval = RECOVERY_CHECK_INTERVAL;
				continue;
			}

			/*
			 * check host_id lease renewal
			 */

			if (sp->align_size > check_buf_len) {
				if (check_buf)
					free(check_buf);
				check_buf_len = sp->align_size;
				check_buf = malloc(check_buf_len);
			}
			if (check_buf)
				memset(check_buf, 0, check_buf_len);

			check_all = 0;

			rv = check_our_lease(sp, &check_all, check_buf);
			if (rv)
				sp->renew_fail = 1;

			if (rv || sp->external_remove || (external_shutdown > 1)) {
				log_space(sp, "set killing_pids check %d remove %d",
					  rv, sp->external_remove);
				sp->space_dead = 1;
				sp->killing_pids = 1;
				kill_pids(sp);
				check_interval = RECOVERY_CHECK_INTERVAL;

			} else if (check_all) {
				check_other_leases(sp, check_buf);
			}
		}
		empty = list_empty(&spaces);
		pthread_mutex_unlock(&spaces_mutex);

		if (external_shutdown && empty)
			break;

		if (external_shutdown == 1) {
			log_debug("ignore shutdown, lockspace exists");
			external_shutdown = 0;
		}

		free_lockspaces(0);
		free_resources();

		gettimeofday(&now, NULL);
		ms = time_diff(&last_check, &now);
		if (ms < check_interval)
			poll_timeout = check_interval - ms;
		else
			poll_timeout = 1;
	}

	free_lockspaces(1);

	daemon_shutdown_reply();

	return 0;
}
```

2. 同时定时检查每个Lockspace的租约是否正常更新。

- src/lockspace.c

```
int check_our_lease(struct space *sp, int *check_all, char *check_buf)
{
	int id_renewal_fail_seconds, id_renewal_warn_seconds;
	uint64_t last_success;
	int corrupt_result;
	int gap;

	pthread_mutex_lock(&sp->mutex);
	last_success = sp->lease_status.renewal_last_success;
	corrupt_result = sp->lease_status.corrupt_result;

	if (sp->lease_status.renewal_read_count > sp->lease_status.renewal_read_check) {
		/*
		 * NB. it's unfortunate how subtle this is.
		 * main loop will pass this buf to check_other_leases next
		 */
		sp->lease_status.renewal_read_check = sp->lease_status.renewal_read_count;
		*check_all = 1;
		if (check_buf)
			memcpy(check_buf, sp->lease_status.renewal_read_buf, sp->align_size);
	}
	pthread_mutex_unlock(&sp->mutex);

	if (corrupt_result) {
		log_erros(sp, "check_our_lease corrupt %d", corrupt_result);
		return -1;
	}

	gap = monotime() - last_success;

	id_renewal_fail_seconds = calc_id_renewal_fail_seconds(sp->io_timeout);
	id_renewal_warn_seconds = calc_id_renewal_warn_seconds(sp->io_timeout);

	if (gap >= id_renewal_fail_seconds) {
		log_erros(sp, "check_our_lease failed %d", gap);
		return -1;
	}

	if (gap >= id_renewal_warn_seconds) {
		log_erros(sp, "check_our_lease warning %d last_success %llu",
			  gap, (unsigned long long)last_success);
	}

	if (com.debug_renew > 1) {
		log_space(sp, "check_our_lease good %d %llu",
		  	  gap, (unsigned long long)last_success);
	}

	return 0;
}

```

3. 如果更新租约失败，并超过一段时间则调用kill_pids函数终止持有该Lockspace的租约的进程。

- src/main.c

遍历这个Lockspace的所有client（每个client代表一个获取Resources的客户），向helper进程发送kill掉他的命令。

```
static void kill_pids(struct space *sp)
{
	struct client *cl;
	uint64_t now, last_success;
	int id_renewal_fail_seconds;
	int ci, sig;
	int do_kill, in_grace;

	/*
	 * all remaining pids using sp are stuck, we've made max attempts to
	 * kill all, don't bother cycling through them
	 */
	if (sp->killing_pids > 1)
		return;

	id_renewal_fail_seconds = calc_id_renewal_fail_seconds(sp->io_timeout);

	/*
	 * If we happen to renew our lease after we've started killing pids,
	 * the period we allow for graceful shutdown will be extended. This
	 * is an incidental effect, although it may be nice. The previous
	 * behavior would still be ok, where we only ever allow up to
	 * kill_grace_seconds for graceful shutdown before moving to sigkill.
	 */
	pthread_mutex_lock(&sp->mutex);
	last_success = sp->lease_status.renewal_last_success;
	pthread_mutex_unlock(&sp->mutex);

	now = monotime();

	for (ci = 0; ci <= client_maxi; ci++) {
		do_kill = 0;

		cl = &client[ci];
		pthread_mutex_lock(&cl->mutex);

		if (!cl->used)
			goto unlock;

		if (cl->pid <= 0)
			goto unlock;

		/* NB this cl may not be using sp, but trying to
		   avoid the expensive client_using_space check */

		if (cl->kill_count >= kill_count_max)
			goto unlock;

		if (cl->kill_count && (now - cl->kill_last < 1))
			goto unlock;

		if (!client_using_space(cl, sp))
			goto unlock;

		cl->kill_last = now;
		cl->kill_count++;

		/*
		 * the transition from using killpath/sigterm to sigkill
		 * is when now >=
		 * last successful lease renewal +
		 * id_renewal_fail_seconds +
		 * kill_grace_seconds
		 */

		in_grace = now < (last_success + id_renewal_fail_seconds + kill_grace_seconds);

		if (sp->external_remove || (external_shutdown > 1)) {
			sig = SIGKILL;
		} else if ((kill_grace_seconds > 0) && in_grace && cl->killpath[0]) {
			sig = SIGRUNPATH;
		} else if (in_grace) {
			sig = SIGTERM;
		} else {
			sig = SIGKILL;
		}

		/*
		 * sigterm will be used in place of sigkill if restricted
		 * sigkill will be used in place of sigterm if restricted
		 */

		if ((sig == SIGKILL) && (cl->restricted & SANLK_RESTRICT_SIGKILL))
			sig = SIGTERM;

		if ((sig == SIGTERM) && (cl->restricted & SANLK_RESTRICT_SIGTERM))
			sig = SIGKILL;

		do_kill = 1;
 unlock:
		pthread_mutex_unlock(&cl->mutex);

		if (!do_kill)
			continue;

		send_helper_kill(sp, cl, sig);
	}
}

```

4. 向helper进程发送kill命令，helper进程进行kill，但是并不向主进程返回执行结果。

- src/main.c

填充相应的数据结构，并向管道写入命令：

```
/*
 * We cannot block the main thread on this write, so the pipe is
 * NONBLOCK, and write fails with EAGAIN when the pipe is full.
 * With 512 msg size and 64k default pipe size, the pipe will be full
 * if we quickly send kill messages for 128 pids.  We retry
 * the kill once a second, so we'll retry the write again in
 * a second.
 *
 * By setting the pipe size to 1MB in setup_helper, we could quickly send 2048
 * msgs before getting EAGAIN.
 */

static void send_helper_kill(struct space *sp, struct client *cl, int sig)
{
	struct helper_msg hm;
	int rv;

	/*
	 * We come through here once a second while the pid still has
	 * leases.  We only send a single RUNPATH message, so after
	 * the first RUNPATH goes through we set CL_RUNPATH_SENT to
	 * avoid futher RUNPATH's.
	 */

	if ((cl->flags & CL_RUNPATH_SENT) && (sig == SIGRUNPATH))
		return;

	if (helper_kill_fd == -1) {
		log_error("send_helper_kill pid %d no fd", cl->pid);
		return;
	}

	memset(&hm, 0, sizeof(hm));

	if (sig == SIGRUNPATH) {
		hm.type = HELPER_MSG_RUNPATH;
		memcpy(hm.path, cl->killpath, SANLK_HELPER_PATH_LEN);
		memcpy(hm.args, cl->killargs, SANLK_HELPER_ARGS_LEN);

		/* only include pid if it's requested as a killpath arg */
		if (cl->flags & CL_KILLPATH_PID)
			hm.pid = cl->pid;
	} else {
		hm.type = HELPER_MSG_KILLPID;
		hm.sig = sig;
		hm.pid = cl->pid;
	}

	log_erros(sp, "kill %d sig %d count %d", cl->pid, sig, cl->kill_count);

 retry:
	rv = write(helper_kill_fd, &hm, sizeof(hm));
	if (rv == -1 && errno == EINTR)
		goto retry;

	/* pipe is full, we'll try again in a second */
	if (rv == -1 && errno == EAGAIN) {
		helper_full_count++;
		log_space(sp, "send_helper_kill pid %d sig %d full_count %u",
			  cl->pid, sig, helper_full_count);
		return;
	}

	/* helper exited or closed fd, quit using helper */
	if (rv == -1 && errno == EPIPE) {
		log_erros(sp, "send_helper_kill EPIPE");
		close_helper();
		return;
	}

	if (rv != sizeof(hm)) {
		/* this shouldn't happen */
		log_erros(sp, "send_helper_kill pid %d error %d %d",
			  cl->pid, rv, errno);
		close_helper();
		return;
	}

	if (sig == SIGRUNPATH)
		cl->flags |= CL_RUNPATH_SENT;
}

```

5. 当进程被杀死后，主进程main_loop函数在与该进程连接poll套接字时，会收到POLLIN和POLLHUP事件，从而执行如下函数，释放client相关资源：

- src/main.c

```
static int main_loop(void)
{
...
			if (pollfd[i].revents & (POLLERR | POLLHUP | POLLNVAL)) {
				deadfn = client[i].deadfn;
				if (deadfn)
					deadfn(i);
			}
...
}

void client_pid_dead(int ci)
{
	struct client *cl = &client[ci];
	int cmd_active;
	int i, pid;

	/* cmd_acquire_thread may still be waiting for the tokens
	   to be acquired.  if it is, cl->pid_dead tells it to release them
	   when finished.  Similarly, cmd_release_thread, cmd_inquire_thread
	   are accessing cl->tokens */

	pthread_mutex_lock(&cl->mutex);
	if (!cl->used || cl->fd == -1 || cl->pid == -1) {
		/* should never happen */
		pthread_mutex_unlock(&cl->mutex);
		log_error("client_pid_dead %d,%d,%d u %d a %d s %d bad state",
			  ci, cl->fd, cl->pid, cl->used,
			  cl->cmd_active, cl->suspend);
		return;
	}

	log_debug("client_pid_dead %d,%d,%d cmd_active %d suspend %d",
		  ci, cl->fd, cl->pid, cl->cmd_active, cl->suspend);

	if (cl->kill_count)
		log_error("dead %d ci %d count %d", cl->pid, ci, cl->kill_count);

	cmd_active = cl->cmd_active;
	pid = cl->pid;
	cl->pid = -1;
	cl->pid_dead = 1;

	/* when cmd_active is set and cmd_a,r,i_thread is done and takes
	   cl->mutex to set cl->cmd_active to 0, it will see cl->pid_dead is 1
	   and know they need to release cl->tokens and call client_free */

	/* make poll() ignore this connection */
	pollfd[ci].fd = -1;
	pollfd[ci].events = 0;

	pthread_mutex_unlock(&cl->mutex);

	/* it would be nice to do this SIGKILL as a confirmation that the pid
	   is really gone (i.e. didn't just close the fd) if we always had root
	   permission to do it */

	/* kill(pid, SIGKILL); */

	if (cmd_active) {
		log_debug("client_pid_dead %d,%d,%d defer to cmd %d",
			  ci, cl->fd, pid, cmd_active);
		return;
	}

	/* use async release here because this is the main thread that we don't
	   want to block doing disk lease i/o */

	pthread_mutex_lock(&cl->mutex);
	for (i = 0; i < cl->tokens_slots; i++) {
		if (cl->tokens[i]) {
			release_token_async(cl->tokens[i]);
			free(cl->tokens[i]);
		}
	}

	_client_free(ci);
	pthread_mutex_unlock(&cl->mutex);
}

```

## 处理设置killpath命令的函数

- src/cmd.c

命令处理函数：

```
void call_cmd_thread(struct task *task, struct cmd_args *ca)
{
	switch (ca->header.cmd) {
	case SM_CMD_ACQUIRE:
		cmd_acquire(task, ca);
		break;
	case SM_CMD_RELEASE:
		cmd_release(task, ca);
		break;
	case SM_CMD_INQUIRE:
		cmd_inquire(task, ca);
		break;
	case SM_CMD_CONVERT:
		cmd_convert(task, ca);
		break;
	case SM_CMD_REQUEST:
		cmd_request(task, ca);
		break;
	case SM_CMD_ADD_LOCKSPACE:
		strcpy(client[ca->ci_in].owner_name, "add_lockspace");
		cmd_add_lockspace(ca);
		break;
	case SM_CMD_INQ_LOCKSPACE:
		strcpy(client[ca->ci_in].owner_name, "inq_lockspace");
		cmd_inq_lockspace(ca);
		break;
	case SM_CMD_REM_LOCKSPACE:
		strcpy(client[ca->ci_in].owner_name, "rem_lockspace");
		cmd_rem_lockspace(ca);
		break;
	case SM_CMD_ALIGN:
		cmd_align(task, ca);
		break;
	case SM_CMD_WRITE_LOCKSPACE:
		cmd_write_lockspace(task, ca);
		break;
	case SM_CMD_WRITE_RESOURCE:
		cmd_write_resource(task, ca);
		break;
	case SM_CMD_READ_LOCKSPACE:
		cmd_read_lockspace(task, ca);
		break;
	case SM_CMD_READ_RESOURCE:
		cmd_read_resource(task, ca);
		break;
	case SM_CMD_READ_RESOURCE_OWNERS:
		cmd_read_resource_owners(task, ca);
		break;
	case SM_CMD_EXAMINE_LOCKSPACE:
	case SM_CMD_EXAMINE_RESOURCE:
		cmd_examine(task, ca);
		break;
	case SM_CMD_KILLPATH:
		cmd_killpath(task, ca);
		break;
	case SM_CMD_SET_LVB:
		cmd_set_lvb(task, ca);
		break;
	case SM_CMD_GET_LVB:
		cmd_get_lvb(task, ca);
		break;
	case SM_CMD_SHUTDOWN_WAIT:
		cmd_shutdown_wait(task, ca);
		break;
	case SM_CMD_SET_EVENT:
		cmd_set_event(task, ca);
		break;
	};
}

```

一个进程只能设置自己的killpath，而不能设置其他进程的：

```
/* N.B. the api doesn't support one client setting killpath for another
   pid/client */

static void cmd_killpath(struct task *task, struct cmd_args *ca)
{
	struct client *cl;
	int cl_ci = ca->ci_target;
	int cl_fd = ca->cl_fd;
	int cl_pid = ca->cl_pid;
	int rv, result, pid_dead;

	cl = &client[cl_ci];

	log_debug("cmd_killpath %d,%d,%d flags %x",
		  cl_ci, cl_fd, cl_pid, ca->header.cmd_flags);

	rv = recv(cl_fd, cl->killpath, SANLK_HELPER_PATH_LEN, MSG_WAITALL);
	if (rv != SANLK_HELPER_PATH_LEN) {
		log_error("cmd_killpath %d,%d,%d recv path %d %d",
			  cl_ci, cl_fd, cl_pid, rv, errno);
		memset(cl->killpath, 0, SANLK_HELPER_PATH_LEN);
		memset(cl->killargs, 0, SANLK_HELPER_ARGS_LEN);
		result = -ENOTCONN;
		goto done;
	}

	rv = recv(cl_fd, cl->killargs, SANLK_HELPER_ARGS_LEN, MSG_WAITALL);
	if (rv != SANLK_HELPER_ARGS_LEN) {
		log_error("cmd_killpath %d,%d,%d recv args %d %d",
			  cl_ci, cl_fd, cl_pid, rv, errno);
		memset(cl->killpath, 0, SANLK_HELPER_PATH_LEN);
		memset(cl->killargs, 0, SANLK_HELPER_ARGS_LEN);
		result = -ENOTCONN;
		goto done;
	}

	cl->killpath[SANLK_HELPER_PATH_LEN - 1] = '\0';
	cl->killargs[SANLK_HELPER_ARGS_LEN - 1] = '\0';

	if (ca->header.cmd_flags & SANLK_KILLPATH_PID)
		cl->flags |= CL_KILLPATH_PID;

	result = 0;
 done:
	pthread_mutex_lock(&cl->mutex);
	pid_dead = cl->pid_dead;
	cl->cmd_active = 0;
	pthread_mutex_unlock(&cl->mutex);

	if (pid_dead) {
		/* release tokens in case a client sets/changes its killpath
		   after it has acquired leases */
		release_cl_tokens(task, cl);
		client_free(cl_ci);
		return;
	}

	send_result(cl_fd, &ca->header, result);
	client_resume(ca->ci_in);
}

```

- 发送修改killpath的消息给sanlock身份的守护进程；
- src/client.c

```
int sanlock_killpath(int sock, uint32_t flags, const char *path, char *args)
{
	char path_max[SANLK_HELPER_PATH_LEN];
	char args_max[SANLK_HELPER_ARGS_LEN];
	int rv, datalen;

	datalen = SANLK_HELPER_PATH_LEN + SANLK_HELPER_ARGS_LEN;

	memset(path_max, 0, sizeof(path_max));
	memset(args_max, 0, sizeof(args_max));

	snprintf(path_max, SANLK_HELPER_PATH_LEN-1, "%s", path);
	snprintf(args_max, SANLK_HELPER_ARGS_LEN-1, "%s", args);

	rv = send_header(sock, SM_CMD_KILLPATH, flags, datalen, 0, -1);
	if (rv < 0)
		return rv;

	rv = send_data(sock, path_max, SANLK_HELPER_PATH_LEN, 0);
	if (rv < 0) {
		rv = -errno;
		goto out;
	}

	rv = send_data(sock, args_max, SANLK_HELPER_ARGS_LEN, 0);
	if (rv < 0) {
		rv = -errno;
		goto out;
	}

	rv = recv_result(sock);
 out:
	return rv;
}

```

## libvirt中lockfailure相关的源码分析

- libvirt中使用on_lockfailure标签来设置虚拟机的锁失败后的处理，其处理方法如下（src/conf/domain_conf.h）：

```
typedef enum {
    VIR_DOMAIN_LOCK_FAILURE_DEFAULT,
    VIR_DOMAIN_LOCK_FAILURE_POWEROFF,
    VIR_DOMAIN_LOCK_FAILURE_RESTART,
    VIR_DOMAIN_LOCK_FAILURE_PAUSE,
    VIR_DOMAIN_LOCK_FAILURE_IGNORE,

    VIR_DOMAIN_LOCK_FAILURE_LAST
} virDomainLockFailureAction;

```

- 目前只支持“默认”、“关机”和“暂停”的处理方式 ，如果是默认则不做任何处理，相当于让sanlock自己处理（src/locking/lock_driver_sanlock.c）。

```
virLockManagerSanlockRegisterKillscript(int sock,
                                        const char *vmuri,
                                        const char *uuidstr,
                                        virDomainLockFailureAction action)
{
    virBuffer buf = VIR_BUFFER_INITIALIZER;
    char *path;
    char *args = NULL;
    int ret = -1;
    int rv;

    switch (action) {
    case VIR_DOMAIN_LOCK_FAILURE_DEFAULT:
        return 0;

    case VIR_DOMAIN_LOCK_FAILURE_POWEROFF:
    case VIR_DOMAIN_LOCK_FAILURE_PAUSE:
        break;

    case VIR_DOMAIN_LOCK_FAILURE_RESTART:
    case VIR_DOMAIN_LOCK_FAILURE_IGNORE:
    case VIR_DOMAIN_LOCK_FAILURE_LAST:
        virReportError(VIR_ERR_CONFIG_UNSUPPORTED,
                       _("Failure action %s is not supported by sanlock"),
                       virDomainLockFailureTypeToString(action));
        goto cleanup;
    }

    virBufferEscape(&buf, '\\', "\\ ", "%s", vmuri);
    virBufferAddLit(&buf, " ");
    virBufferEscape(&buf, '\\', "\\ ", "%s", uuidstr);
    virBufferAddLit(&buf, " ");
    virBufferEscape(&buf, '\\', "\\ ", "%s",
                    virDomainLockFailureTypeToString(action));

    if (virBufferCheckError(&buf) < 0)
        goto cleanup;

    /* Unfortunately, sanlock_killpath() does not use const for either
     * path or args even though it will just copy them into its own
     * buffers.
     */
    path = (char *) VIR_LOCK_MANAGER_SANLOCK_KILLPATH;
    args = virBufferContentAndReset(&buf);

    VIR_DEBUG("Register sanlock killpath: %s %s", path, args);

    /* sanlock_killpath() would just crop the strings */
    if (strlen(path) >= SANLK_HELPER_PATH_LEN) {
        virReportError(VIR_ERR_INTERNAL_ERROR,
                       _("Sanlock helper path is longer than %d: '%s'"),
                       SANLK_HELPER_PATH_LEN - 1, path);
        goto cleanup;
    }
    if (strlen(args) >= SANLK_HELPER_ARGS_LEN) {
        virReportError(VIR_ERR_INTERNAL_ERROR,
                       _("Sanlock helper arguments are longer than %d:"
                         " '%s'"),
                       SANLK_HELPER_ARGS_LEN - 1, args);
        goto cleanup;
    }

    if ((rv = sanlock_killpath(sock, 0, path, args)) < 0) {
        if (rv <= -200) {
            virReportError(VIR_ERR_INTERNAL_ERROR,
                           _("Failed to register lock failure action:"
                             " error %d"), rv);
        } else {
            virReportSystemError(-rv, "%s",
                                 _("Failed to register lock failure"
                                   " action"));
        }
        goto cleanup;
    }

    ret = 0;

 cleanup:
    VIR_FREE(args);
    return ret;
}

```

- 如果是“关机”或“暂停”的处理方式则执行如下程序，且不可更改（src/locking/lock_driver_sanlock.c）:

```
#define VIR_LOCK_MANAGER_SANLOCK_KILLPATH LIBEXECDIR "/libvirt_sanlock_helper"

```

- libvirt_sanlock_helper程序目前只支持“关机”和“暂停”（src/locking/sanlock_helper.c）。

```
int
main(int argc, char **argv)
{
    const char *uri;
    const char *uuid;
    virDomainLockFailureAction action;
    char *xml = NULL;
    virConnectPtr conn = NULL;
    virDomainPtr dom = NULL;
    int ret = EXIT_FAILURE;

    int authTypes[] = {
        VIR_CRED_AUTHNAME,
        VIR_CRED_ECHOPROMPT,
        VIR_CRED_PASSPHRASE,
        VIR_CRED_NOECHOPROMPT,
    };
    virConnectAuth auth = {
        .credtype = authTypes,
        .ncredtype = ARRAY_CARDINALITY(authTypes),
        .cb = authCallback,
    };

    if (virGettextInitialize() < 0)
        exit(EXIT_FAILURE);

    if (getArgs(argc, argv, &uri, &uuid, &action) < 0)
        goto cleanup;

    if (!(conn = virConnectOpenAuth(uri, &auth, 0)) ||
        !(dom = virDomainLookupByUUIDString(conn, uuid)))
        goto cleanup;

    switch (action) {
    case VIR_DOMAIN_LOCK_FAILURE_POWEROFF:
        if (virDomainDestroy(dom) == 0 ||
            virDomainIsActive(dom) == 0)
            ret = EXIT_SUCCESS;
        break;

    case VIR_DOMAIN_LOCK_FAILURE_PAUSE:
        if (virDomainSuspend(dom) == 0)
            ret = EXIT_SUCCESS;
        break;

    case VIR_DOMAIN_LOCK_FAILURE_DEFAULT:
    case VIR_DOMAIN_LOCK_FAILURE_RESTART:
    case VIR_DOMAIN_LOCK_FAILURE_IGNORE:
    case VIR_DOMAIN_LOCK_FAILURE_LAST:
        fprintf(stderr, _("unsupported failure action: '%s'\n"),
                virDomainLockFailureTypeToString(action));
        break;
    }

 cleanup:
    virObjectUnref(dom);
    if (conn)
        virConnectClose(conn);
    VIR_FREE(xml);

    return ret;
}

```

## 总结

- 当sanlock续租失败时、默认情况下首先使用SIGTERM杀死进程。过一段时间后，如果还不成功，则会使用SIGKILL杀死进程。
- 当libvirt使用sanlock时，默认情况下不对续租进行处理，由sanlock使用自己的配置进行处理。
- 当libvirt使用sanlock时，也可以通过配置虚拟机的“on_lockfailure”事件来进行处理续租失败的问题。
- 不过目前libvirt的“on_lockfailure”事件只支持“pause”和“poweroff”这两种动作。
- 在续租失败时，sanlock会通过kill函数或执行killpath程序来终止进程，通过套接字连接状态来判断进程是否已经终止，如果未终止则不会释放相关资源。
