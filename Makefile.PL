use ExtUtils::MakeMaker;

WriteMakefile(
    'dist'      => { 'COMPRESS'  => 'gzip', 'SUFFIX'    => '.gz', },
    'NAME'	=> 'WordNet::QueryData',
    'VERSION_FROM'   => 'QueryData.pm',
);
