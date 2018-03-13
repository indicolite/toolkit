#include <unistd.h>
#include <stdio.h>
#include <sys/socket.h>
#include <sys/types.h>
#include <sys/un.h>

const char path[]="/tmp/server";
int ask_nova(){
    int server_fd,client_fd;
    struct sockaddr_un server_addr, client_addr;
    unlink(path);
    server_fd = socket(AF_UNIX,SOCK_STREAM,0);
    if(server_fd == -1){
        perror("socket: ");
        exit(1);
    }
    server_addr.sun_family=AF_UNIX;
    strcpy(server_addr.sun_path,path);
    if(connect(server_fd,(struct sockaddr *)&server_addr,sizeof(server_addr)) == -1){
        perror("connect: ");
        exit(1);
    }
    char recv[105],send[105];
    int i;
    puts("the client started, please enter your message: ");
    while(1){
/**
        memset(send,0,sizeof(send));
        if(read(server_fd,send,105)==-1){
        //if(read(STDIN_FILENO,send,105)==-1){
            perror("read: ");
            break;
        }
**/
        memset(send,0,sizeof(send));
        strcpy(send, "kill_or_not");
	    if(write(server_fd,send,strlen(send))==-1){
	        perror("send: ");
            break;
        }

        memset(send,0,sizeof(send));
        if(write(server_fd,send,strlen(send))==-1){
            perror("send: ");
            break;
        }

        /**
        if(strcmp(send,"kill\n")==0){
            printf("the client process end.\n");
            break;
        }
        **/
        memset(recv,0,sizeof(recv));

        if(read(server_fd,recv,105)==-1){
            perror("recv: ");
            break;
        }
        if(strcmp(recv,"kill\n")==0){
            printf("the client process end.\n");
            //break;
            return -1;
        }else {
            printf("recv message from server: %s",recv);
	        return 0;
	    }
        printf("recv message from server: %s",recv);
    }
    close(server_fd);
    unlink(path);
    return 0;
}

void main(){
    while(1){
        int result = ask_nova();
        if (result == -1) {
            	//kill_pids(sp);
            	printf("abnormal state\n");
        } else {
            	//log_erros("all pids existing");
            	printf("normal state\n");
        }
    }
}
