# -*- mode: cperl -*-

requires 'perl', '5.008005';

requires 'DBI';

on configure => sub {
    requires 'Module::Build::Tiny', '0.039';
};

on develop => sub {
    requires 'App::scan_prereqs_cpanfile', '0.09';
    requires 'Pod::Wordlist';
    requires 'Test::Fixme';
    requires 'Test::Kwalitee', '1.21';
    requires 'Test::Spelling', '0.12';
    requires 'Test::More', '0.96';
    requires 'Test::Vars';
    requires 'Test::Pod', '1.41';
};

on test => sub {
    requires 'Test::More', '0.88';
};
