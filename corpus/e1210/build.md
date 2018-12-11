[TOC]
## pgloader
```
indicolite@:~/homework/e1210|⇒  pgloader mysql://root:xxxxx@192.168.2.208/movie pgsql:///movie_neo4j
2018-12-11T07:43:50.078000Z LOG Data errors in '/private/tmp/pgloader/'
2018-12-11T07:43:50.081000Z LOG Migrating from #<MYSQL-CONNECTION mysql://root@192.168.2.208:3306/movie {10056F97B3}>
2018-12-11T07:43:50.081000Z LOG Migrating into #<PGSQL-CONNECTION pgsql://indicolite@UNIX:5432/movie_neo4j {100583CE93}>
2018-12-11T07:43:50.999000Z ERROR PostgreSQL Database error 23503: insert or update on table "movie_to_genre" violates foreign key constraint "genre_movie_id"
DETAIL: Key (genre_id)=(10769) is not present in table "genre".
QUERY: ALTER TABLE movie.movie_to_genre ADD CONSTRAINT genre_movie_id FOREIGN KEY(genre_id) REFERENCES movie.genre(genre_id) ON UPDATE NO ACTION ON DELETE NO ACTION
2018-12-11T07:43:51.021000Z LOG report summary reset
             table name     errors       rows      bytes      total time
-----------------------  ---------  ---------  ---------  --------------
        fetch meta data          0         16                     0.339s
         Create Schemas          0          0                     0.005s
       Create SQL Types          0          0                     0.007s
          Create tables          0         10                     0.049s
         Set Table OIDs          0          5                     0.008s
-----------------------  ---------  ---------  ---------  --------------
            movie.genre          0         19     0.2 kB          0.017s
            movie.movie          0       4519     1.3 MB          0.169s
   movie.movie_to_genre          0       7899    77.6 kB          0.053s
  movie.person_to_movie          0      14452   185.9 kB          0.094s
           movie.person          0        505    52.3 kB          0.100s
-----------------------  ---------  ---------  ---------  --------------
COPY Threads Completion          0          4                     0.264s
         Create Indexes          0          7                     0.194s
 Index Build Completion          0          7                     0.019s
        Reset Sequences          0          0                     0.056s
           Primary Keys          0          5                     0.034s
    Create Foreign Keys          1          3                     0.021s
        Create Triggers          0          0                     0.000s
        Set Search Path          0          1                     0.003s
       Install Comments          0          0                     0.000s
-----------------------  ---------  ---------  ---------  --------------
      Total import time          ✓      27394     1.6 MB          0.591s
```

## 参考链接
[基于电影知识图谱的智能问答系统][https://blog.csdn.net/appleyk/article/category/7667380]
[from-mysql-to-postgresql][https://tapoueh.org/blog/2017/07/from-mysql-to-postgresql/]
