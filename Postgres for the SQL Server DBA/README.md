## Prerequisites for Hands-on participation
I'm excited that you'll be joining me in class to take some of your first steps with PostgreSQL. Depending on the length of the training you are attending, it may be more challenging to follow along as I teach and run code, but if you are setup and ready to go with the prerequisites below, I'd love for you to try PostgreSQL with me.


### 1. A working PostGIS installation
During class, access to external resources are never guaranteed. Therefore it
is beneficial to have a local installation of PostgreSQL running and accessible.

While many of the sample scripts will run regardless of which PostgreSQL database
you use, some later exercises will utilize the sample Bluebox database which
requires PostGIS, a PostgreSQL extension, to be installed and available.

Therefore, the easiest approach is to use Docker if you have it. If you use Docker,
**_I highly suggest you use the image that I've created for use in class linked below_**. It is a working
PostGIS Postgres database with a handful of other extensions available that we will
talk about in class.

**Ryan's Bluebox PostgreSQL Docker image:** 
- URL: [hub.docker.com/r/ryanbooz/bluebox-postgres/tags](https://hub.docker.com/r/ryanbooz/bluebox-postgres/tags)
 - Docker Pull command: `docker pull ryanbooz/bluebox-postgres:latest`

Alternatively, you can install PostgreSQL locally using one of the methods discussed in the first part of
the Simple Talk article linked below, and then install the PostGIS extension
afterwards.

[Installing and Getting Connected to PostgreSQL for the First Time](https://www.red-gate.com/simple-talk/databases/postgresql/getting-connected-to-postgresql-for-the-first-time/)

### 2. Postgres CLI tools
PostgreSQL ships with numerous command line tools that run on all platforms. These include
`psql`, `pg_dump`, `pg_restore`, and others. We will be discussing and using each of these
commands and so it's most helpful if you have access to them.

If you're running a Docker container and are comfortable running interactive shell terminal in the
container, it contains all of the command line PostgreSQL tools.

Otherwise, you can install them locally to access from a terminal. This Simple Talk article discusses
all of the various ways you can install `psql` and the other command line tools on various platforms.

https://www.red-gate.com/simple-talk/databases/postgresql/getting-connected-to-postgresql-for-the-first-time/

### 3. DBeaver or equivalent IDE
When you install PostgreSQL in almost any form, the command line tools will be installed as well, including `psql` which is useful for getting connected and running simpler queries. We'll talk about some of this in class.

However, having a graphical IDE is often useful for learning a new version of SQL for the helpful intellisense and ease of use. I generally recommend DBeaver Community edition as a good IDE to start with. If you already have access to another tool like pgAdmin or Datagrip, those will work as well.

[DBeaver Download](https://dbeaver.io/download/)

### 3. Bluebox Database
There are many sample databases that you can use to learn more about PostgreSQL. However, I've developed (and continue to enhance) a sample database that utilizes various features of PostgreSQL for us to explore during class.

Clone or download a ZIP of the Bluebox repository to get the database dump file which can be restored to any Postgres/PostGIS installation to use in class.

We will discuss restoring database backups earlier in the class in case you aren't able to restore it on your own. But please download the dump file ahead of time.

[Bluebox Github Repository](https://github.com/ryanbooz/bluebox)