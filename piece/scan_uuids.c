static void scan_uuids(void)
{
	time_t rawtime;
	FILE *outfile;

	int ci;
	outfile = fopen("/tmp/temp_uuid.txt", "w+");
	if (outfile == NULL) {
		log_debug("fopen temp_uuid file failed");
	}
	char tempf[256];
	FILE *tempfile;
	int c;
	for (ci = 0; ci <= client_maxi; ci++) {
		if (client[ci].pid > 0) {
			log_debug("in ask_hastack: cmd_kill %d %s", client[ci].pid, client[ci].owner_name);
			//fprintf(outfile, "%s\n", client[ci].owner_name);
			sprintf(tempf, "/proc/%d/cmdline", client[ci].pid);
			tempfile=fopen(tempf, "r");
			if (tempfile) {
				//while ((c = getc(tempfile)) != ',') {
				while ((c = getc(tempfile)) != EOF) {
					fprintf(outfile,"%c", c);
				}
			}
			fprintf(outfile, "\n");
			fclose(tempfile);
		}
	}
	fclose(outfile);
	char cmds[]="awk --re-interval '{print gensub(/(^.*)([a-z0-9]{8}-[a-z0-9]{4}-[a-z0-9]{4}-[a-z0-9]{4}-[a-z0-9]{12})(.*$)/,\"\\\\2\",\"g\")}' /tmp/temp_uuid.txt > /tmp/temp_uuids.txt";
	FILE *of;
	int fd;
	of = fopen("/tmp/awks.sh", "w+");
	if (of == NULL) {
		log_debug("generate /tmp/awks failed");
	}
	fprintf(of, "%s", cmds);
	fclose(of);
	fd = open("/tmp/awks.sh", O_RDONLY);
	fchmod(fd, S_IRWXU|S_IRWXG|S_IRWXO|S_IXOTH);
	close(fd);
	const char * envp[] = {"PWD=/tmp", NULL};
	if (fork()==0) {
		if (execle("/bin/bash", "bash", "/tmp/awks.sh", NULL, envp) == -1) {
			log_debug("exec awks.sh failed");
		}
		exit(1);
	}

	sleep(2);
        //if ((fp = popen("PWD=/tmp awk --re-interval '{print gensub(/(^.*)([a-z0-9]{8}-[a-z0-9]{4}-[a-z0-9]{4}-[a-z0-9]{4}-[a-z0-9]{12})(.*$)/,\"\\2\",\"g\")}' /tmp/temp_uuid.txt > /tmp/temp_uuids.txt", "r")) == NULL) {
	//awk --re-interval '{print gensub(/(^.*)([a-z0-9]{8}-[a-z0-9]{4}-[a-z0-9]{4}-[a-z0-9]{4}-[a-z0-9]{12})(.*$)/,"\\2","g")}'
	//	log_debug("in scan_uuids(), generate /tmp/temp_uuids.txt failed");
	//}
	
	time(&rawtime);
	char new_file[255];
	sprintf(new_file,"/var/lib/hastack/detach_vms/vms_%lu",(unsigned long)time(NULL));
	//sprintf(new_file,"/tmp/bingo_%lu",(unsigned long)time(NULL));
	log_debug("filename: %s", new_file);
	char oldname[] = "/tmp/temp_uuids.txt";
	int rel = rename(oldname, new_file);
	if (rel == 0) {
	        log_debug("file temp_uuid rename succeed");
	} else {
	        log_debug("failed to rename file temp_uuid");
	}
}
