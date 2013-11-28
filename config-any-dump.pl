#!/usr/bin/perl
use strict;
use warnings;

# use Getopt::Long;
use Getopt::Long::Descriptive qw(-all);
use File::Temp;
use File::Slurp qw(slurp);
use Sysadm::Install qw(:all);
use Data::Dumper;

#use Config::Any;
use Config::Any::Merge;
binmode STDOUT, ":utf8";

local $Data::Dumper::Indent = 1;

my ( $opt, $usage ) = describe_options(
    "Dumpen einer Config-Datei mit Config-Any-Merge\n"
        . 'Aufruf:%c %o files ...',
    [ 'cmd|c=s', 'Kommando: (load|dump)', { default => 'dump' } ],
    [ 'merge|m', 'alle Config-Dateien werdebn zusammengefuehrt' ],
    [   'read-from=s',
        'config-Eingabe-Datei: (pl, yaml, json, ini, html)',
        { default => 'yaml' }
    ],
    [   'dump-to=s',
        'in anderes config-Format ausgeben: (pl, yml, json, ini, html)',
        { default => 'pl' }
    ],
    [ 'out-file|O=s', 'Ausgabedatei', {default=>'-'} ],
    [ 'utf-8',     'Kodierung utf-8' ],
    [ 'dry-run|n', 'Kommando nicht ausfuehren' ],
    [ 'debug|x',   'Debugmeldungen ausgeben' ],
    [ 'verbose|v', 'Zusatzinformationen ausgeben' ],
    [ 'help|h',    'diese Hilfe ausgeben' ],
);
print( $usage->text ), exit if $opt->help;

Sysadm::Install::dry_run( $opt->{dry_run} );

# Open the config
my $supported_extensions = join( '|', map {$_} Config::Any->extensions() );
my $config = undef;
my $fhTmp;
my $fTmp = '';
if ( @ARGV == 0 ) {
    my $data = join( '', (<>) );
    $fhTmp = File::Temp->new(
        TEMPLATE => "config-any-dump-XXXXXX",
        UNLINK   => 1,
        SUFFIX   => '.' . $opt->{read_from}
    );
    $fTmp = $fhTmp->filename;

    #blurt( $data, $fTmp, {utf8 => 1} );
    if ( $opt->{utf_8} ) {
        blurt( $data, $fTmp, { utf8 => 1 } );
    }
    else {
        blurt( $data, $fTmp );
    }
    push( @ARGV, $fTmp );
}
foreach my $file (@ARGV) {
    my @files = glob($file);
    @files = grep { -f $_ } grep {/\.($supported_extensions)/} @files;
    if ( $opt->{merge} ) {
        $config = Config::Any::Merge->load_files(
            { files => [@files], use_ext => 1, overrite => 0 } );
    }
    else {
        $config = Config::Any->load_files(
            { files => [@files], use_ext => 1, overrite => 0 } );
    }

          ( $opt->{dump_to} eq 'json' ) ? output(dump_to_json($config))
        : ( $opt->{dump_to} eq 'yaml' ) ? output(dump_to_yaml($config))
        : ( $opt->{dump_to} eq 'ini' )  ? output(dump_to_ini($config))
        : ( $opt->{dump_to} eq 'conf' ) ? output(dump_to_conf($config))
        : ( $opt->{dump_to} eq 'html' ) ? output(dump_to_html($config))
        :                                 output(Dumper($config));
}
exit(0);

sub output {
    my ($text) = @_;
    if ($opt->{out_file} ne '-') {
        blurt($text, $opt->{out_file});
    } else {
        print $text;
    }
}

sub dump_to_yaml {
    my ($config) = @_;
    use YAML::XS;
    return YAML::XS::Dump($config);
}

sub dump_to_json {
    my ($config) = @_;
    use JSON::XS;
    my $coder                    = JSON::XS->new->ascii->pretty->allow_nonref;
    my $pretty_printed_unencoded = $coder->encode($config);
    return $pretty_printed_unencoded;
}

sub dump_to_inis {
    my ($config) = @_;
    use Config::Tiny;
    my $Config = Config::Tiny->new;
    $Data::Dumper::Deepcopy = 1;
    $Config->{config} = {%$config};
    my $ini_string = $Config->write_string($Config);
    $Config->write('a.ini');
    return $ini_string;
}

sub dump_to_ini {
    my ($config) = @_;
    use Config::General qw(ParseConfig SaveConfigString);
    return my $content = SaveConfigString($config);
}

sub dump_to_html {
    my ($config) = @_;
    use JSON::XS;

    #print JSON::XS::Dump($config);
    #print new->utf8->encode ($config)
}

sub dump_single_file {
    my ($config_file) = @_;
    if ( -f $config_file ) {
        my $config = Config::Any->load_files(
            {   files    => ["$config_file"],
                use_ext  => 1,
                overrite => 0
            }
        );
        print Dumper($config);
    }
    else {
        print STDERR "Datei:'$config_file' existiert nicht!\n";
    }
}
