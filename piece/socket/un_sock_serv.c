#include <unistd.h>
#include <stdio.h>
#include <sys/socket.h>
#include <sys/types.h>
#include <sys/un.h>

const char path[]="/tmp/server";
int main(){
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
    if(bind(server_fd,(struct sockaddr *)&server_addr,sizeof(server_addr))==-1){
        perror("bind: ");
        exit(1);
    }
    listen(server_fd,10);  //server listen most 10 requests.
    puts("server is listening: ");
    int client_len=sizeof(client_addr);
    client_fd=accept(server_fd,(struct sockaddr *)&client_addr,(int *)&client_len);
    if(client_fd == -1){
        perror("accept: ");
        exit(1);
    }
    char recv[105], send[105];
    int i;
    while(1){
        memset(recv,0,sizeof(recv));
        if(read(client_fd,recv,105)==-1){
            perror("read: ");
            break;
        }
        if(strcmp(recv,"end\n")==0){
            printf("the server process end.\n");
            break;
        }
        printf("recv message from client: %s",recv);
        memset(send,0,sizeof(send));
        if(read(STDIN_FILENO,send,sizeof(send))==-1){
            perror("read: ");
            break;
        }
        if(write(client_fd,send,strlen(send))==-1){
            perror("write: ");
            break;
        }
    }
    close(server_fd);
    unlink(path);
}
