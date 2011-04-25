use inc::Module::Install;

name       'Test-Spelling';
all_from   'lib/Test/Spelling.pm';
repository 'http://github.com/bestpractical/test-spelling';

requires 'Pod::Spell' => '1.01';

test_requires 'Test::More' => 0;
test_requires 'File::Temp' => 0;

WriteAll;

