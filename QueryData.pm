# -*- perl -*-
#
# Package to interface with WordNet (wn) command line program
# written by Jason Rennie <jrennie@mitre.org>, July 1999

# Run 'perldoc' on this file to produce documentation

# Copyright 1999 Jason Rennie <jrennie@ai.mit.edu>

# This module is free software; you can redistribute it and/or modify
# it under the same terms as Perl itself.

# $Id: QueryData.pm,v 1.2 1999/09/15 19:53:50 jrennie Exp $

package WordNet::QueryData;

use strict;
use Carp;
use FileHandle;
use Exporter;

##############################
# Environment/Initialization #
##############################

BEGIN {
    use vars qw($VERSION @ISA @EXPORT @EXPORT_OK);
    # List of classes from which we are inheriting methods
    @ISA = qw(Exporter);
    # Automatically loads these function names to be used without qualification
    @EXPORT = qw();
    # Allows these functions to be used without qualification
    @EXPORT_OK = qw();
    $VERSION = do { my @r=(q$Revision: 1.2 $=~/\d+/g); sprintf "%d."."%02d"x$#r,@r };
}

#############################
# Private Package Variables #
#############################

# Mapping of possible part of speech to single letter used by wordnet
my %pos_map = ('noun'      => 'n',
	       'n'         => 'n',
	       '1'         => 'n',
	       ''          => 'n',
	       'verb'      => 'v',
	       'v'         => 'v',
	       '2'         => 'v',
	       'adjective' => 'a',
	       'adj'       => 'a',
	       'a'         => 'a',
	       # Adj satellite is essentially just an adjective
	       's'         => 'a',
	       '3'         => 'a',
	       'adverb'    => 'r',
	       'adv'       => 'r',
	       'r'         => 'r',
	       '4'         => 'r');
# Mapping of possible part of speech to corresponding number
my %pos_num = ('noun'      => '1',
	       'n'         => '1',
	       '1'         => '1',
	       ''          => '1',
	       'verb'      => '2',
	       'v'         => '2',
	       '2'         => '2',
	       'adjective' => '3',
	       'adj'       => '3',
	       'a'         => '3',
	       # Adj satellite is essentially just an adjective
	       's'         => '3',
	       '3'         => '3',
	       'adverb'    => '4',
	       'adv'       => '4',
	       'r'         => '4',
	       '4'         => '4');
# Mapping from WordNet symbols to short relation names
my %relation_sym = ('!'  => 'ants',
		    '@'  => 'hype',
		    '~'  => 'hypo',
		    '#m' => 'mmem',
		    '#s' => 'msub',
		    '#p' => 'mprt',
		    '%m' => 'hmem',
		    '%s' => 'hsub',
		    '%p' => 'hprt',
		    '='  => 'attr',
		    '*'  => 'enta',
		    '>'  => 'caus',
		    '^'  => 'also',
		    '\$' => 'vgrp',
		    '&'  => 'sim',
		    '<'  => 'part',
		    '\\' => 'pert');
# Mapping from long relation names to short relation names
my %relation_long = ('synset'            => 'syns',
		     'antonym'           => 'ants',
		     'hypernym'          => 'hype',
		     'hyponym'           => 'hypo',
		     'member meronym'    => 'mmem',
		     'substance meronym' => 'msub',
		     'part meronym'      => 'mprt',
		     'member holonym'    => 'hmem',
		     'substance holonym' => 'hsub',
		     'part holonym'      => 'hprt',
		     'attribute'         => 'attr',
		     'entailment'        => 'enta',
		     'cause'             => 'caus',
		     'also see'          => 'also',
		     'verb group'        => 'vgrp',
		     'similar to'        => 'sim',
		     'participle'        => 'part',
		     'pertainym'         => 'pert');

# Default location of WordNet dictionary files
my $wordnet_dir = "/usr/local/dict";

# WordNet data file names
my @exc_file = ("", "noun.exc", "verb.exc", "adj.exc", "adv.exc");
my @index_file = ("", "index.noun", "index.verb", "index.adj", "index.adv");
my @data_file = ("", "data.noun", "data.verb", "data.adj", "data.adv");

END { } # module clean-up code here (global destructor)

###############
# Subroutines #
###############

# Convert string to lower case; also translate '_' to ' '
sub lower
{ 
    my $word = shift;
    $word =~ tr/A-Z_/a-z /;
    return $word;
}

# Perform all initialization for new WordNet class instance
sub _initialize
{
    my $self = shift;
    # Load morphology exclusion mapping
    $self->load_exclusions ();
    $self->load_index ();
    $self->open_data ();
}

sub new
{
    # First argument is class
    my $class = shift;
    # Second is location of WordNet dictionary; Third is verbosity
    
    my $self = {};
    bless $self, $class;
    $self->{wordnet_dir} = @_ ? shift : $wordnet_dir;
    $self->{verbose} = @_ ? shift : 0;
    warn "Dir = ", $self->{wordnet_dir}, "\n" if ($self->{verbose});
    warn "Verbose = ", $self->{verbose}, "\n" if ($self->{verbose});
    $self->_initialize ();
    return $self;
}

# Object destructor
sub DESTROY
{
    my $self = shift;
    my $i;
    # Close data.* files
    for ($i=1; $i <= 4; $i++)
    {
	undef $self->{data_fh}->[$i];
    }
}

# Load mapping to non-standard canonical form of words (morphological
# exceptions)
sub load_exclusions
{
    my $self = shift;
    my ($exc, $word, $i);

    for ($i=1; $i <= 4; $i++)
    {
	open (FILE, $self->{wordnet_dir}."/$exc_file[$i]")
	    || die "Not able to open ".$self->{wordnet_dir}."/$exc_file[$i]: $!\n";
	while (<FILE>)
	{
	    my ($exc, $word);
	    ($exc, $word) = $_ =~ m/^(\S+)\s+(\S+)/;
	    $exc = lower ($exc);
	    $word = lower ($word);
	    $self->{morph_exc}->[$i]->{$exc} = $word;
	}
	close (FILE);
    }
    # Return reference to array of hash
}

sub load_index 
{
    my $self = shift;
    my ($i, $j);

    for ($i=1; $i <= 4; $i++)
    {
	open (FILE, $self->{wordnet_dir}."/$index_file[$i]")
	    || die "Not able to open ".$self->{wordnet_dir}."/$index_file[$i]: $!\n";
	# Throw away initial lines that begin with a space
	while (<FILE>) { last if (m/^\S/); }
	# Process rest of file
	while (1)
	{
	    my ($word, $pos, $poly_cnt, $pointer_cnt, @stuff) = split (/\s+/);
	    # Canonicalize syntax of word
	    $word = lower ($word);
	    print STDERR "Incorrect part-of-speech for $word (file=",
	      $index_file[$i], ", pos=$pos)\n" if ($pos ne $pos_map{$i});
	    splice (@stuff, 0, $pointer_cnt);
	    my ($sense_cnt, $tagsense_cnt, @synset_offset) = @stuff;

	    $self->{index}->[$pos_num{$pos}]->{$word} = pack "i*", @synset_offset;
	    # Get the next word
	    $_ = <FILE>;
	    last if (!$_);
	}
	close (FILE);
    }
}


# Open data files and return file handles
sub open_data
{
    my $self = shift;
    my $i;

    for ($i=1; $i <= 4; $i++)
    {
	$self->{data_fh}->[$i] = new FileHandle "<".$self->{wordnet_dir}."/$data_file[$i]";
	die "Not able to open ".$self->{wordnet_dir}."/$data_file[$i]: $!\n"
	    if (!defined ($self->{data_fh}->[$i]));
    }
}


# Generate list of all possible forms of how word may be found in WordNet
sub forms
{
    my ($self, $word, $pos) = @_;
    my ($i, $j);

    die "QueryData: \"$pos\" not a legal part of speech!\n"
	if (!defined ($pos_num{$pos}));
    $pos = $pos_num{$pos};

    # Canonicalize word
    $word = lower ($word);
    print STDERR "forms ($word, $pos)\n" if ($self->{verbose});
    return $self->{morph_exc}->[$pos]->{$word} if (defined ($self->{morph_exc}->[$pos]->{$word}));

    my @token = split (/\s+/, $word);
    my @token_form;

    # Find all possible forms for all tokens
    for ($i=0; $i < @token; $i++)
    {
	push @{$token_form[$i]}, $token[$i];
	if ($pos_num{$pos} == 1)
	{
	    push @{$token_form[$i]}, $1 if ($token[$i] =~ m/^(\w+)s$/);
	    push @{$token_form[$i]}, $1 if ($token[$i] =~ m/^(\w+s)es$/);
	    push @{$token_form[$i]}, $1 if ($token[$i] =~ m/^(\w+x)es$/);
	    push @{$token_form[$i]}, $1 if ($token[$i] =~ m/^(\w+z)es$/);
	    push @{$token_form[$i]}, $1 if ($token[$i] =~ m/^(\w+ch)es$/);
	    push @{$token_form[$i]}, $1 if ($token[$i] =~ m/^(\w+sh)es$/);
	}
	elsif ($pos_num{$pos} == 2)
	{
	    push @{$token_form[$i]}, $1 if ($token[$i] =~ m/^(\w+)s$/);
	    push @{$token_form[$i]}, $1."y" if ($token[$i] =~ m/^(\w+)ies$/);
	    push @{$token_form[$i]}, $1 if ($token[$i] =~ m/^(\w+e)s$/);
	    push @{$token_form[$i]}, $1 if ($token[$i] =~ m/^(\w+)es$/);
	    push @{$token_form[$i]}, $1 if ($token[$i] =~ m/^(\w+e)d$/);
	    push @{$token_form[$i]}, $1 if ($token[$i] =~ m/^(\w+)ed$/);
	    push @{$token_form[$i]}, $1."e" if ($token[$i] =~ m/^(\w+)ing$/);
	    push @{$token_form[$i]}, $1 if ($token[$i] =~ m/^(\w+)ing$/);
	}
	elsif ($pos_num{$pos} == 3)
	{
	    push @{$token_form[$i]}, $1 if ($token[$i] =~ m/^(\w+)er$/);
	    push @{$token_form[$i]}, $1 if ($token[$i] =~ m/^(\w+)est$/);
	    push @{$token_form[$i]}, $1 if ($token[$i] =~ m/^(\w+e)r$/);
	    push @{$token_form[$i]}, $1 if ($token[$i] =~ m/^(\w+e)st$/);
	}
    }
    # Generate all possible token sequences (collocations)
    my @index; for ($i=0; $i < @token; $i++) { $index[$i] = 0; }
    my @word_form;
    while (1)
    {
	my $this_word;
	# String together one sequence of possibilities
	for ($i=0; $i < @token; $i++)
	{
	    $this_word .= " ".$token_form[$i]->[$index[$i]] if (defined ($this_word));
	    $this_word = $token_form[$i]->[$index[$i]] if (!defined ($this_word));
	}
	push @word_form, $this_word;

	# Increment counter
	for ($i=0; $i < @token; $i++)
	{
	    $index[$i]++;
	    # Exit loop if we don't need to increment next index
	    last if ($index[$i] < @{$token_form[$i]});
	    # Otherwise, reset this value, increment next index
	    $index[$i] = 0;
	}
	# If we had to reset every index, we have tried all possibilities
	last if ($i >= @token);
    }	
    return @word_form;
}


# Given a line from data.pos, store pointer relations in %{$pointer}
sub get_pointers
{
    my ($line, $pointer, $index_offset) = @_;
    my $i;

    my ($offset, $lex_file, $ss_type, $w_cnt, @stuff) = split (/\s+/, $line);
    print STDERR "Offsets differ INDEX=$index_offset DATA=$offset\n"
	if ($index_offset != $offset);
    # Strip words
    my (@word_info) = splice @stuff, 0, $w_cnt*2;
    # Get pointers
    my ($p_cnt) = splice (@stuff, 0, 1);
    my (@pointer_info) = splice (@stuff, 0, $p_cnt*4);
    for ($i=0; $i < $p_cnt; $i++)
    {
	my ($type, $offset, $pos, $srctgt) = splice (@pointer_info, 0, 4);
	push @{$pointer->{$relation_sym{$type}}}, "$offset\#$pos";
    }
    my $key;
}


# Given a data file offset and part of speech, returns a fully qualified
# word correpsonding to that offset/pos
sub get_all_words
{
    my ($self, $index_offset, $pos) = @_;
    my ($i, @rtn);

    my $fh = $self->{data_fh}->[$pos_num{$pos}];
    seek $fh, $index_offset, 0;
    $_ = <$fh>;
    my ($offset, undef, undef, $w_cnt, @stuff) = split (/\s+/);
    print STDERR "Offsets differ INDEX=$index_offset DATA=$offset\n"
	if ($index_offset != $offset);
    # Grab words
    my (@words) = splice @stuff, 0, $w_cnt*2;
    # Get rid of lex file number junk
    for ($i=1; $i <= $w_cnt; $i++) { splice @words, $i, 1; }
    foreach my $word (@words)
    {
	$word = lower ($word);
	my @offset_array = (unpack "i*", $self->{index}->[$pos_num{$pos}]->{$word});
	for ($i=0; $i < @offset_array; $i++)
	{
	    push @rtn, "$word\#$pos\#".($i+1) if ($offset_array[$i] == $index_offset);
	    last if ($offset_array[$i] == $index_offset);
	}
    }
    return @rtn;
}

# Given a data file offset and part of speech, returns a fully qualified
# word correpsonding to that offset/pos
sub get_word
{
    my ($self, $index_offset, $pos) = @_;
    my $i;

    my $fh = $self->{data_fh}->[$pos_num{$pos}];
    seek $fh, $index_offset, 0;
    $_ = <$fh>;
    my ($offset, undef, undef, undef, $word) = split (/\s+/);
    $word = lower ($word);
    
    print STDERR "Offsets differ INDEX=$index_offset DATA=$offset\n"
	if ($index_offset != $offset);
    my @offset_array = (unpack "i*", $self->{index}->[$pos_num{$pos}]->{$word});
    for ($i=0; $i < @offset_array; $i++)
    {
	return "$word\#$pos\#".($i+1) if ($offset_array[$i] == $index_offset);
    }
}


# Main query funciton.  Accepts a query string and a string corresponding
# to a relation that is to be returned.  
sub query
{
    my $self = shift;
    # The query string (word, pos and sense #)
    my $string = shift;
    # The relation about which to return information
    # Only required for fully-qualified query (word, pos and sense #)
    my $relation = shift;
    my $i;

    if ($string =~ /^([^\#]+)\#([^\#]+)\#(\d+)$/)
    {
	my ($word, $pos, $sense) = ($1, $2, $3);
	print STDERR "query: WORD=$word POS=$pos SENSE=$sense RELATION=$relation\n" if ($self->{verbose});
	# Translate POS to number, check for legal POS,
	print STDERR "query: Illegal Part-of-speech: POS=$pos WORD=$word\n"
	    if (!$pos_num{$pos});

	print STDERR "Second argument must be a valid relation!\n"
	    if (!defined ($relation));
	return () if (!defined ($relation));
	# Map to abbreviation if relation name is in long or symbol form
	$relation = $relation_long{$relation} if ($relation_long{$relation});
	$relation = $relation_sym{$relation} if ($relation_sym{$relation});

	my $fh = $self->{data_fh}->[$pos_num{$pos}];
	# Each entry should be an array reference.  Each element in the
	# array should be a pos-qualified offset (OFFSET#POS)
	my %pointer;
	# Sense number can be obtained from offset pointer ordering in index.*

	# Data file pointer
	my $index_offset =
	    (unpack "i*", $self->{index}->[$pos_num{$pos}]->{$word})[$sense-1];
	seek $fh, $index_offset, 0;
	# Get line corresponding to sense
	$_ = <$fh>;
	# Add synset relation
	push @{$pointer{syns}}, "$index_offset\#$pos";
	get_pointers ($_, \%pointer, $index_offset);

	# Create list of meronyms
	push @{$pointer{mero}}, @{$pointer{mmem}} if ($pointer{mmem});
	push @{$pointer{mero}}, @{$pointer{msub}} if ($pointer{msub});
	push @{$pointer{mero}}, @{$pointer{mprt}} if ($pointer{mprt});
	# Create list of holonyms
	push @{$pointer{holo}}, @{$pointer{hmem}} if ($pointer{hmem});
	push @{$pointer{holo}}, @{$pointer{hsub}} if ($pointer{hsub});
	push @{$pointer{holo}}, @{$pointer{hprt}} if ($pointer{hprt});
	
	# If the relation is invalid, exit prematurely
	if (!$pointer{$relation})
	{
	    if ($self->{verbose}) {
		print STDERR "No such relation ($relation) for word \'$word\'\n";
		print STDERR "Valid relations: syns, ants, hype, hypo, mmem, msub, mprt, mero, hmem, hsub, hprt, holo, attr, enta, caus, also, vgrp, sim, part, pert\n";
	    }
	    return ();    
	}
	
	# For syns, we must return all word/pos/sense tuples for this
	# synset (not just the representative one)
	return $self->get_all_words ($index_offset, $pos)
	    if ($relation eq "syns");

	my @rtn;
	foreach my $syn (@{$pointer{$relation}})
	{
	    my ($offset, $pos) = $syn =~ /^(\d+)\#([^\#]+)$/;
	    push @rtn, $self->get_word ($offset, $pos);
	}
	return @rtn;
    }
    elsif ($string =~ /^([^\#]+)\#([^\#]+)$/)
    {
	# Given word/pos, find out what senses exist.
	# Return list of word/pos/sense tuples
	my ($word, $pos) = (lower ($1), $2);
	print STDERR "query: WORD=$word POS=$pos\n" if ($self->{verbose});
	# Translate POS to number, check for legal POS,
	print STDERR "query: Illegal Part-of-speech: POS=$pos WORD=$word\n"
	    if (!$pos_num{$pos});

	my (@rtn, $i);
	my @pointers = unpack "i*", $self->{index}->[$pos_num{$pos}]->{$word};
	my $sense_cnt = scalar @pointers;
	for ($i=0; $i < @pointers; $i++) {
	    push @rtn, "$string\#".($i+1);
	}
	return @rtn;
    }
    elsif ($string =~ /^([^\#]+)$/)
    {
	# Given word, find out what parts of speech we have information
	# about.  Return list of word/pos pairs
	my $word = lower ($1);
	print STDERR "query: WORD=$word\n" if ($self->{verbose});
	my ($i, @words);
	for ($i=1; $i <= 4; $i++)
	{
	    push @words, "$word\#".$pos_map{$i}
	      if ($self->{index}->[$i]->{$word});
	}
	return @words;
    }
    else
    {
	print STDERR "Illegal query string.  Must be of one of these forms:\n";
	print STDERR "\n";
	print STDERR "1) WORD#POS#SENSE\n";
	print STDERR "2) WORD#POS\n";
	print STDERR "3) WORD\n";
	print STDERR "\n";
	print STDERR "Where WORD is an English word, POS is a part of\n";
	print STDERR "speech (n,v,a,r) and SENSE is a sense number\n";
    }
}

# module must return true
1;
__END__

#################
# Documentation #
#################

=head1 NAME

WordNet::QueryData - direct perl interface to WordNet database

=head1 SYNOPSIS

use WordNet::QueryData;

# Load index, mophological exclusion files---slow process
my $wn = WordNet::QueryData->new ("/usr/local.foo/dict", 1);

# Possible forms that you might find 'ghostliest' in WordNet
print "Ghostliest-> ", join (", ", $wn->forms ("ghostliest", 3)), "\n";

# Synset of cat, sense #7
print "Cat#7-> ", join (", ", $wn->query ("cat#n#7", "synset")), "\n";

# Hyponyms of cat, sense #1 (house cat)
print "Cat#1-> ", join (", ", $wn->query ("cat#n#1", "hyponym")), "\n";

# Senses of run as a verb
print "Run->", join (", ", $wn->query ("run#verb")), "\n";

=head1 DESCRIPTION

WordNet::QueryData provides a direct interface to the WordNet database
files.  It requires the WordNet package
(http://www.cogsci.princeton.edu/~wn/).  It allows the user direct
access to the full WordNet semantic lexicon.  All parts of speech are
supported and access is generally very efficient because the index and
morphical exclusion tables are loaded at initialization.  Things are
more or less optimized for long sessions of queries---the 'new'
invocation load the entire index table and all of the morphological
exclusions.  My PII/400 takes about 15 seconds to do this.  Memory
usage is on the order of 18 Megs.  If I get enough requests, I may
work on making this a less demanding step.  Once the index and
morph. exc. files are loaded, queries are very fast.

=head1 USAGE

To use the WordNet::QueryData module, incorporate the package with
"use WordNet::QueryData;".  Then, establish an instance of the package
with "my $wn = new WordNet::QueryData ("/usr/local/dict");".  If the
WordNet dict directory is not /usr/local/dict on your system, pass the
correct directory as the first argument of the function call.  You may
pass a second argument of 1 if you wish the module to print out
progress and verbose error messages.

WordNet::QueryData is object-oriented.  You can establish multiple
instances simply by using 'new' multiple times, however, the only
practical use I can see for this is comparing data from different
WordNet versions.  I did the module OO-style because I had never done
an OO perl module, figured it was time to learn and thought it might
make the code a bit cleaner.  The WordNet::QueryData object has two
object functions that you might want to use, 'forms' and 'query'.
'query' is the function that gives you access to all of the WordNet
relations.  It accepts a query string and a relation.  The query
string may be at one of three specification levels:

1) WORD (e.g. dog)
2) WORD#POS (e.g. house#noun)
3) WORD#POS#SENSE (e.g. ghostly#adj#1)

WORD is simply an english word.  Spaces should be used to separate
tokens (not underscores as is used in the WordNet database).  Case
does not matter.  At this time, the word must exactly match one of the
words in the WordNet database files.  You can use 'forms' to search
for the form of a word that WordNet contains.  Eventually, I'll
integrate this with 'query' so that no manual search is necessary.

POS is the part of speech.  Use 'n' for noun, 'v' for verb, 'a' for
adjective and 'r' for adverb.  You may also use full names and some
abbreviations (as above and in test.pl).

SENSE is the sense number that uniquely identifies the sense of the word.

Query #1 will return a list of WORD#POS strings, one for each part of
speech that the word is used as.  Query #2 will return a list of
WORD#POS#SENSE strings.  Query #1 and #2 are essentially used to
search for the sense for which you are looking.  When making such a
query, no relation (2nd argument) should be passed to 'query'.  Query
#3 is the interesting one and allows you to make use of all of the
WordNet relations.  It requires a second argument, a relation, which
may be one of the following:

syns - synset words
ants - antonyms
hype - hypernyms
hypo - hyponyms
mmem - member meronyms
msub - substance meronyms
mprt - part meronyms
mero - all meronyms
hmem - member holonyms
hsub - substance holonyms
hprt - part holonyms
holo - all holonyms
attr - attributes (?)
enta - entailment (verbs only)
caus - cause (verbs only)
also - also see
vgrp - verb group (verbs only)
sim - similar to (adjectives only)
part - participle of verb (adjectives only)
pert - pertainym (pertains to noun) (adjectives only)

Longer names are also allowed.  Each relation returns a list of
strings.  Each string is in WORD#POS#SENSE form and corresponds to a
specific sense.  In the case of 'syns', one string is returned for
each word that is part of the synset.  For other relations, a single
string is returned for each synset (you can map 'syns' on to the
returned array to get the words for a relation).  In the case of
relations like 'hype' and 'hypo', query returns only the immediate
hypernyms or hyponyms.  You can use 'query' recursively to get a full
hyper/hyponym tree.

=head1 NOTES

Requires existence of WordNet database files (stored in 'dict' directory).

=head1 COPYRIGHT

Copyright 1999 Jason Rennie <jrennie@ai.mit.edu>  All rights reserved.

This module is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 SEE ALSO

perl(1)

http://www.cogsci.princeton.edu/~wn/

http://www.ai.mit.edu/~jrennie/WordNet/

=head1 LOG

$Log: QueryData.pm,v $
Revision 1.2  1999/09/15 19:53:50  jrennie
add url

Revision 1.1  1999/09/15 13:27:44  jrennie
new QueryData directory

Revision 1.3  1999/09/15 12:16:59  jrennie
(get_all_words): fix
allow long relation names; allow long POS names; check for illegal POS

Revision 1.2  1999/09/14 22:23:35  jrennie
first draft of direct access to WordNet data files; 'new'ing is slow; about 15 seconds on my PII/400.  Memory consumption using WordNet 1.6 is appx. 16M.  Still need to integrate forms into query.  query requires the word form to be exactly like that in WordNet (although caplitalization may differ)

Revision 1.1  1999/09/13 14:59:35  jrennie
access data files directly; us a more OO style of coding; initialization (new) code is pretty much done; forms is done

=cut

