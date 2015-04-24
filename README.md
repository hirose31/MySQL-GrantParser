<div>
    <a href="https://travis-ci.org/hirose31/MySQL-GrantParser"><img src="https://travis-ci.org/hirose31/MySQL-GrantParser.png?branch=master" alt="Build Status" /></a>
    <a href="https://coveralls.io/r/hirose31/MySQL-GrantParser?branch=master"><img src="https://coveralls.io/repos/hirose31/MySQL-GrantParser/badge.png?branch=master" alt="Coverage Status" /></a>
</div>

# NAME

MySQL::GrantParser - parse SHOW GRANTS and return as hash reference

# SYNOPSIS

    use MySQL::GrantParser;
    
    # connect with existing dbh
    my $dbh = DBI->connect(...);
    my $grant_parser = MySQL::GrantParser->new(
        dbh => $dbh;
    );
    
    # connect with user, password
    my $grant_parser = MySQL::GrantParser->new(
        user     => 'root',
        password => 'toor',
        hostname => '127.0.0.1',
    );
    
    # and parse!
    my $grants = $grant_parser->parse; # => HashRef

# DESCRIPTION

MySQL::GrantParser is SHOW GRANTS parser for MySQL, inspired by Ruby's [Gratan](http://gratan.codenize.tools/).

This module returns privileges for all users as following hash reference.

    {
        'USER@HOST' => {
            'user' => USER,
            'host' => HOST,
            'objects' => {
                'DB_NAME.TABLE_NAME' => {
                    privs => [ PRIV_TYPE, PRIV_TYPE, ... ],
                    with  => 'GRANT OPTION',
                },
                ...
            },
            'options' => {
                'identified' => '...',
                'required'   => '...',
            },
        },
        {
            ...
        },
    }

For example, this GRANT statement

    GRANT SELECT, INSERT, UPDATE, DELETE ON orcl.* TO 'scott'@'%' IDENTIFIED BY 'tiger' WITH GRANT OPTION;

is represented as following.

    {
        'scott@%' => {
            user => 'scott',
            host => '%',
            objects => {
                '*.*' => {
                    privs => [
                        'USAGE'
                    ],
                    with => '',
                },
                '`orcl`.*' => {
                    privs => [
                        'SELECT',
                        'INSERT',
                        'UPDATE',
                        'DELETE',
                    ],
                    with => 'GRANT OPTION',
                }
            },
            options => {
                identified => "PASSWORD XXX",
                required => '',
            },
        },
    }

# METHODS

## Class Methods

### **new**(%args:Hash) :MySQL::GrantParser

Creates and returns a new MySQL::GrantParser instance. Dies on errors.

%args is following:

- dbh => DBI:db

    Database handle object.

- user => Str
- password => Str
- hostname => Str
- socket => Str

    Path of UNIX domain socket for connecting.

Mandatory arguments are `dbh` or `hostname` or `socket`.

## Instance Methods

### **parse**() :HashRef

Parse privileges and return as hash reference.

# AUTHOR

HIROSE Masaaki <hirose31@gmail.com>

# REPOSITORY

[https://github.com/hirose31/MySQL-GrantParser](https://github.com/hirose31/MySQL-GrantParser)

    git clone https://github.com/hirose31/MySQL-GrantParser.git

patches and collaborators are welcome.

# SEE ALSO

[Gratan](http://gratan.codenize.tools/),
[http://dev.mysql.com/doc/refman/5.6/en/grant.html](http://dev.mysql.com/doc/refman/5.6/en/grant.html)

# COPYRIGHT

Copyright HIROSE Masaaki

# LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.
