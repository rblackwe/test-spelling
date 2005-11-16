use 5.006;
use ExtUtils::MakeMaker;

WriteMakefile (
    'NAME'           => 'Test::Spelling',
    'VERSION_FROM'   => 'lib/Test/Spelling.pm',
    'PREREQ_PM'      => {
        'Pod::Spell'            => '1.01',
        'Test::More'            => 0,
        'File::Spec'            => 0,
        'File::Temp'            => 0,
        'Carp'                  => 0,
    },
);

