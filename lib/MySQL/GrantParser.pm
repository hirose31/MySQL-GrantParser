package MySQL::GrantParser;

use strict;
use warnings;
use 5.008_005;

our $VERSION = '1.001';

use DBI;
use Carp;

use Data::Dumper;
$Data::Dumper::Indent    = 1;
$Data::Dumper::Deepcopy  = 1;
$Data::Dumper::Sortkeys  = 1;
$Data::Dumper::Terse     = 1;
$Data::Dumper::Useqq     = 1;
$Data::Dumper::Quotekeys = 0;
sub p(@) { ## no critic
    my $d =  Dumper(\@_);
    $d =~ s/\\x{([0-9a-z]+)}/chr(hex($1))/ge;
    print $d;
}

sub new {
    my($class, %args) = @_;

    my $self = {
        dbh             => undef,
        need_disconnect => 0,
    };
    if (exists $args{dbh}) {
        $self->{dbh} = delete $args{dbh};
    } else {
        if (!$args{hostname} && !$args{socket}) {
            Carp::croak("missing mandatory args: hostname or socket");
        }

        my $dsn = "DBI:mysql:";
        for my $p (
            [qw(hostname hostname)],
            [qw(port port)],
            [qw(socket mysql_socket)],
        ) {
            my $arg_key   = $p->[0];
            my $param_key = $p->[1];
            if ($args{$arg_key}) {
                $dsn .= ";$param_key=$args{$arg_key}";
            }
        }

        $self->{need_disconnect} = 1;
        $self->{dbh} = DBI->connect(
            $dsn,
            $args{user}||'',
            $args{password}||'',
            {
                AutoCommit => 0,
            },
        ) or Carp::croak("$DBI::errstr ($DBI::err)");
    }

    return bless $self, $class;
}

sub parse {
    my $self = shift;
    my %grants;

    # select all user
    my $rset = $self->{dbh}->selectall_arrayref('SELECT user, host FROM mysql.user');

    for my $user_host (@$rset) {
        my ($user, $host) = @{$user_host};
        my $quoted_user_host = $self->quote_user($user, $host);
        my $rset = $self->{dbh}->selectall_arrayref("SHOW GRANTS FOR ${quoted_user_host}");
        my $stmts = $rset->[0];
        %grants = (%grants, %{ parse_stmts($stmts) });
    }

    return \%grants;
}

sub parse_stmts {
    my $stmts = shift;
    my @grants = ();
    for my $stmt (@$stmts) {
        my $parsed = {
            with       => '',
            require    => '',
            identified => '',
            privs      => [],
            object     => '',
            user       => '',
            host       => '',
        };

        if ($stmt =~ s/\s+WITH\s+(.+?)\z//) {
            $parsed->{with} = $1;
        }
        if ($stmt =~ s/\s+REQUIRE\s+(.+?)\z//) {
            $parsed->{require} = $1;
        }
        if ($stmt =~ s/\s+IDENTIFIED BY\s+(.+?)\z//) {
            $parsed->{identified} = $1;
        }
        if ($stmt =~ /\AGRANT\s+(.+?)\s+ON\s+(.+?)\s+TO\s+'(.*)'\@'(.+)'\z/) {
            $parsed->{privs}  = parse_privs($1);
            $parsed->{object} = $2;
            $parsed->{user}   = $3;
            $parsed->{host}   = $4;
        }

        push @grants, $parsed;
    }

    return pack_grants(@grants);
}

sub pack_grants {
    my @grants = @_;
    my $packed;

    for my $grant (@grants) {
        my $user       = delete $grant->{user};
        my $host       = delete $grant->{host};
        my $user_host  = join '@', $user, $host;
        my $object     = delete $grant->{object};
        my $identified = delete $grant->{identified};
        my $required   = delete $grant->{require};

        unless (exists $packed->{$user_host}) {
            $packed->{$user_host} = {
                user    => $user,
                host    => $host,
                objects => {},
                options => {
                    required   => '',
                    identified => '',
                },
            };
        }
        $packed->{$user_host}{objects}{$object}  = $grant;
        $packed->{$user_host}{options}{required} = $required if $required;

        if ($identified) {
            $packed->{$user_host}{options}{identified} = $identified;
        }
    }

    return $packed;
}

sub quote_user {
    my $self = shift;
    my($user, $host) = @_;
    sprintf q{%s@%s}, $self->{dbh}->quote($user), $self->{dbh}->quote($host);
}

sub parse_privs {
    my $privs = shift;
    $privs .= ',';

    my @priv_list = ();

    while ($privs =~ /\G([^,(]+(?:\([^)]+\))?)\s*,\s*/g) {
        push @priv_list, $1;
    }

    return \@priv_list;
}

sub DESTROY {
    my $self = shift;
    if ($self->{need_disconnect}) {
        $self->{dbh} && $self->{dbh}->disconnect;
    }
}

1;

__END__

=encoding utf8

=begin html

<a href="https://travis-ci.org/hirose31/MySQL-GrantParser"><img src="https://travis-ci.org/hirose31/MySQL-GrantParser.png?branch=master" alt="Build Status" /></a>
<a href="https://coveralls.io/r/hirose31/MySQL-GrantParser?branch=master"><img src="https://coveralls.io/repos/hirose31/MySQL-GrantParser/badge.png?branch=master" alt="Coverage Status" /></a>

=end html

=head1 NAME

MySQL::GrantParser - parse SHOW GRANTS and return as hash reference

=begin readme

=head1 INSTALLATION

To install this module, run the following commands:

    perl Build.PL
    ./Build
    ./Build test
    ./Build install

=end readme

=head1 SYNOPSIS

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


=head1 DESCRIPTION

MySQL::GrantParser is SHOW GRANTS parser for MySQL, inspired by Ruby's L<Gratan|http://gratan.codenize.tools/>.

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


=head1 METHODS

=head2 Class Methods

=head3 B<new>(%args:Hash) :MySQL::GrantParser

Creates and returns a new MySQL::GrantParser instance. Dies on errors.

%args is following:

=over 4

=item dbh => DBI:db

Database handle object.

=item user => Str

=item password => Str

=item hostname => Str

=item socket => Str

Path of UNIX domain socket for connecting.

=back

Mandatory arguments are C<dbh> or C<hostname> or C<socket>.

=head2 Instance Methods

=head3 B<parse>() :HashRef

Parse privileges and return as hash reference.

=head1 AUTHOR

HIROSE Masaaki E<lt>hirose31@gmail.comE<gt>

=head1 REPOSITORY

L<https://github.com/hirose31/MySQL-GrantParser>

    git clone https://github.com/hirose31/MySQL-GrantParser.git

patches and collaborators are welcome.

=head1 SEE ALSO

L<Gratan|http://gratan.codenize.tools/>,
L<http://dev.mysql.com/doc/refman/5.6/en/grant.html>

=head1 COPYRIGHT

Copyright HIROSE Masaaki

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

# for Emacsen
# Local Variables:
# mode: cperl
# cperl-indent-level: 4
# cperl-close-paren-offset: -4
# cperl-indent-parens-as-block: t
# indent-tabs-mode: nil
# coding: utf-8
# End:

# vi: set ts=4 sw=4 sts=0 et ft=perl fenc=utf-8 ff=unix :
