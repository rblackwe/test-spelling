package Test::Spelling;

use 5.006;
use strict;
use warnings;
use Pod::Spell;
use Test::Builder;
use File::Spec;
use File::Temp;
use Carp;

our $VERSION = '0.11';

my $Test        = Test::Builder->new;
my $Spell_cmd   = 'spell';
my $Spell_temp  = File::Temp->new->filename;

sub import {
    my $self = shift;
    my $caller = caller;
    no strict 'refs';
    *{$caller.'::pod_file_spelling_ok'}      = \&pod_file_spelling_ok;
    *{$caller.'::all_pod_files_spelling_ok'} = \&all_pod_files_spelling_ok;
    *{$caller.'::add_stopwords'}             = \&add_stopwords;
    *{$caller.'::set_spell_cmd'}             = \&set_spell_cmd;
    *{$caller.'::all_pod_files'}             = \&all_pod_files
        unless defined &{$caller. '::all_pod_files'};

    $Test->exported_to($caller);
    $Test->plan(@_);
}


my $Pipe_err = 0;

sub pod_file_spelling_ok {
    my $file = shift;
    my $name = @_ ? shift : "POD spelling for $file";

    if ( !-f $file ) {
        $Test->ok( 0, $name );
        $Test->diag( "$file does not exist" );
        return;
    }

    # save digested POD to temp file
    my $checker = Pod::Spell->new;
    $checker->parse_from_file($file, $Spell_temp);

    # run spell command and fetch output
    open ASPELL, "$Spell_cmd < $Spell_temp|" 
        or croak "Couldn't run spellcheck command '$Spell_cmd'";
    my @words = <ASPELL>;
    close ASPELL or die;

    # clean up words, remove stopwords, select unique errors
    chomp for @words;
    @words = grep { !$Pod::Wordlist::Wordlist{$_} } @words;
    my %seen;
    @seen{@words} = ();
    @words = map "    $_\n", sort keys %seen;

    # emit output
    my $ok = !@words;
    $Test->ok( $ok, "$name");
    if ( !$ok ) {
        $Test->diag("Errors:\n" . join '', @words);
    }

    return $ok;
}

sub all_pod_files_spelling_ok {
    my @files = all_pod_files(@_);

    $Test->plan( tests => scalar @files );

    my $ok = 1;
    foreach my $file ( @files ) {
        pod_file_spelling_ok( $file, ) or undef $ok;
    }
    return $ok;
}

sub all_pod_files {
    my @queue = @_ ? @_ : _starting_points();
    my @pod = ();

    while ( @queue ) {
        my $file = shift @queue;
        if ( -d $file ) {
            local *DH;
            opendir DH, $file or next;
            my @newfiles = readdir DH;
            closedir DH;

            @newfiles = File::Spec->no_upwards( @newfiles );
            @newfiles = grep { $_ ne "CVS" && $_ ne ".svn" } @newfiles;

            push @queue, map "$file/$_", @newfiles;
        }
        if ( -f $file ) {
            push @pod, $file if _is_perl( $file );
        }
    } # while
    return @pod;
}

sub _starting_points {
    return 'blib' if -e 'blib';
    return 'lib';
}

sub _is_perl {
    my $file = shift;

    return 1 if $file =~ /\.PL$/;
    return 1 if $file =~ /\.p(l|m|od)$/;
    return 1 if $file =~ /\.t$/;

    local *FH;
    open FH, $file or return;
    my $first = <FH>;
    close FH;

    return 1 if defined $first && ($first =~ /^#!.*perl/);

    return;
}


sub add_stopwords {
    for (@_) {
        my $word = $_;
        $word =~ s/^#?\s*//;
        $word =~ s/\s+$//;
        next if $word =~ /\s/ or $word =~ /:/;
        $Pod::Wordlist::Wordlist{$word} = 1;
    }
}

sub set_spell_cmd {
    $Spell_cmd = shift;
}

1;

__END__

=head1 NAME

Test::Spelling - check for spelling errors in POD files

=head1 SYNOPSIS

C<Test::Spelling> lets you check the spelling of a POD file, and report
its results in standard C<Test::Simple> fashion. This module requires the
F<spell> program.

    use Test::More;
    use Test::Spelling;
    plan tests => $num_tests;
    pod_file_spelling_ok( $file, "POD file spelling OK" );

Module authors can include the following in a F<t/pod_spell.t> file and
have C<Test::Spelling> automatically find and check all POD files in a
module distribution:

    use Test::More;
    use Test::Spelling;
    all_pod_files_spelling_ok();

Note, however that it is not really recommended to include this test with a
CPAN distribution, or a package that will run in an uncontrolled environment,
because there's no way of predicting if F<spell> will be available or the
word list used will give the same results (what if it's in a different language,
for example?). You can have the test, but don't add it to F<MANIFEST> (or add
it to F<MANIFEST.SKIP> to make sure you don't add it by accident). Anyway,
your users don't really need to run this test, as it is unlikely that the 
documentation will acquire typos while in transit. :-)

You can add your own stopwords (words that should be ignored by the spell
check):

    add_stopwords(qw(asdf thiswordiscorrect));

These stopwords are global for the test. See L<Pod::Spell> for a variety of
ways to add per-file stopwords to each .pm file.

=head1 DESCRIPTION

Check POD files for spelling mistakes, using L<Pod::Spell> and F<spell> to do
the heavy lifting.

=head1 FUNCTIONS

=head2 pod_file_spelling_ok( FILENAME[, TESTNAME ] )

C<pod_file_spelling_ok()> will okay the test if the POD has no spelling errors.

When it fails, C<pod_file_spelling_ok()> will show any spelling errors as
diagnostics.

The optional second argument TESTNAME is the name of the test.  If it
is omitted, C<pod_file_spelling_ok()> chooses a default test name "POD spelling
for FILENAME".

=head2 all_pod_files_spelling_ok( [@files/@directories] )

Checks all the files in C<@files> for POD spelling.  It runs L<all_pod_files()>
on each file/directory, and calls the C<plan()> function for you (one test for
each function), so you can't have already called C<plan>.

If C<@files> is empty or not passed, the function finds all POD files in
the F<blib> directory if it exists, or the F<lib> directory if not.
A POD file is one that ends with F<.pod>, F<.pl> and F<.pm>, or any file
where the first line looks like a shebang line.

If you're testing a module, just make a F<t/spell.t>:

    use Test::More;
    use Test::Spelling;
    all_pod_files_spelling_ok();

Returns true if all pod files are ok, or false if any fail.

=head2 all_pod_files( [@dirs] )

Returns a list of all the Perl files in I<$dir> and in directories below.
If no directories are passed, it defaults to F<blib> if F<blib> exists,
or else F<lib> if not.  Skips any files in CVS or .svn directories.

A Perl file is:

=over 4

=item * Any file that ends in F<.PL>, F<.pl>, F<.pm>, F<.pod> or F<.t>.

=item * Any file that has a first line with a shebang and "perl" on it.

=back

The order of the files returned is machine-dependent.  If you want them
sorted, you'll have to sort them yourself.

=head2 add_stopwords(@words)

Add words that should be skipped by the spell check. A suggested use is to list
these words, one per line, in the __DATA__ section of your test file, and just
call

    add_stopwords(<DATA>);

As a convenience, C<add_stopwords> will automatically ignore a comment mark and
one or more spaces from the beginning of the line, and it will ignore lines
that say '# Error:' or '# Looks like' or /Failed test/. The reason? Let's say
you run a test and get this result:

    1..1
    not ok 1 - POD spelling for lib/Test/Spelling.pm
    #     Failed test (lib/Test/Spelling.pm at line 70)
    # Errors:
    #     stopwords
    # Looks like you failed 1 tests of 1.

Let's say you decide that all the words that were marked as errors are really
correct. The diagnostic lines are printed to STDERR; that means that, if you
have a decent shell, you can type something like

    perl t/spell.t 2>> t/spell.t

which will append the diagnostic lines to the end of your test file. Assuming
you already have a __DATA__ line in your test file, that should be enough to
ensure that the test passes the next time.

Also note that L<Pod::Spell> skips words believed to be code, such as words
in verbatim blocks and code labeled with CE<lt>>.

=head2 set_spell_cmd($command)

If the F<spell> program has a different name or is not in your path, you can
specify an alternative with C<set_spell_cmd>. Any command that takes text
from standard input and prints a list of misspelled words, one per line, to
standard output will do. For example, you can use C<aspell -l>.

=head1 SEE ALSO

L<Pod::Spell>

=head1 VERSION

0.11

=head1 AUTHOR

Ivan Tubert-Brohman C<< <itub@cpan.org> >>

Heavily based on L<Test::Pod> by Andy Lester and brian d foy.

=head1 COPYRIGHT

Copyright 2005, Ivan Tubert-Brohman, All Rights Reserved.

You may use, modify, and distribute this package under the
same terms as Perl itself.

=cut

