use ExtUtils::MakeMaker;

# It is bad that the default WordNet directories are in two places,
# here and at the beginning of QueryData.pm ($wnHomeUnix and
# $wnHomePC).  These need to be synchronized.  I need to import those
# variables from QueryData.pm.

die "*** Please set the WNHOME environment variable to the location of your\n***   WordNet installation.  QueryData.pm will not work otherwise.\n*** Alternatively, you can make the installation in the default\n***   location, C:\\wn16 on Windows, or /usr/local/wordnet1.7 on unix.\n" unless exists $ENV{WNHOME} or -d "C:\\wn16" or -d "/usr/local/wordnet1.7";

WriteMakefile(
    'dist'      => { 'COMPRESS'  => 'gzip', 'SUFFIX'    => '.gz', },
    'NAME'	=> 'WordNet::QueryData',
    'VERSION_FROM'   => 'QueryData.pm',
);
