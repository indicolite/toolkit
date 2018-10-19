/*************************************************************************
	> File Name: uuid_save.c
	> Author:
	> Mail:
	> Created Time: 四  3/29 20:24:55 2018
 ************************************************************************/

#include <stdio.h>
#include <string.h>
#include <time.h>

int main() {
	char scan_uuids[255];
	char buffer [1024];
	time_t rawtime;
	strcpy(scan_uuids, "ps aux|grep qemu|grep -v grep|awk -F, '{for(i=1;i<=NF;i++){if($i ~/uuid=.*/) {print $i}}}'|sed 's/uuid=//g'");

	FILE *fp, *outfile;
	if ((fp = popen(scan_uuids, "r")) == NULL) {
		printf("popen() error!\n");
	}
	fread(buffer, 1, sizeof(buffer), fp);

	/**
	while((fgets(buffer,sizeof(buffer),fp))!=NULL) {
		printf("%s", buffer);
	}
	**/
	//printf("%s", buffer);
	pclose(fp);
	outfile = fopen("/tmp/temp_uuid.txt", "w+");
	fprintf(outfile, "%s", buffer);
	fclose(outfile);

	time(&rawtime);
	char buffers[255];
	sprintf(buffers,"/tmp/bingo_%lu",(unsigned long)time(NULL));
	printf("filename: %s\n", buffers);
	char oldname[] = "/tmp/temp_uuid.txt";
	int rel = rename(oldname, buffers);
	if (rel == 0) {
		printf("File renamed succeed");
	} else {
		printf("Failed rename file");
	}
	return 0;

	/**
        FILE *fp;
        char buffer[10];
        int num;
        fp = popen(scan_uuids, "r");
	**/

	/**
        while((fgets(buffer,sizeof(buffer),fp))!=NULL)
        {
                int i=strlen(buffer);
                if(buffer[i-1]=='\n')
                {
                        buffer[i-1]=0;
                }
        }
	**/
}
