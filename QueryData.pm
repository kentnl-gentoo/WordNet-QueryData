# -*- perl -*-
#
# Package to interface with WordNet (wn) command line program
# written by Jason Rennie <jrennie@mitre.org>, July 1999

# Run 'perldoc' on this file to produce documentation

# Copyright 1999 Jason Rennie <jrennie@ai.mit.edu>

# This module is free software; you can redistribute it and/or modify
# it under the same terms as Perl itself.

# $Id: QueryData.pm,v 1.14 2002/03/21 11:50:58 jrennie Exp $

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
    $VERSION = do { my @r=(q$Revision: 1.14 $=~/\d+/g); sprintf "%d."."%02d"x$#r,@r };
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
		    '%m' => 'mmem',
		    '%s' => 'msub',
		    '%p' => 'mprt',
		    '#m' => 'hmem',
		    '#s' => 'hsub',
		    '#p' => 'hprt',
		    '='  => 'attr',
		    '*'  => 'enta',
		    '>'  => 'caus',
		    '^'  => 'also',
		    '$' => 'vgrp', # '$' Hack to make font-lock work in emacs
		    '&'  => 'sim',
		    '<'  => 'part',
		    '\\' => 'pert');

# Default location of WordNet dictionary files
my $wordnet_dir = $ENV{"WNHOME"}."/dict";

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
    print STDERR "Loading WordNet data, please wait...\n" if ($self->{verbose});
    # Ensure that input record separator is "\n"
    my $old_separator = $/;
    $/ = "\n";

    # Load morphology exclusion mapping
    $self->load_exclusions ();
    $self->load_index ();
    $self->open_data ();
    print STDERR "Done.\n" if ($self->{verbose});

    # Return setting of input record separator
    $/ = $old_separator;
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

    print STDERR "Morphological Exceptions...\n" if $self->{verbose};
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

    print STDERR "Index...\n" if $self->{verbose};
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

	    $self->{"index"}->[$pos_num{$pos}]->{$word} = pack "i*", @synset_offset;
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

    print STDERR "Data Files...\n" if $self->{verbose};
    for ($i=1; $i <= 4; $i++)
    {
	$self->{data_fh}->[$i] = new FileHandle "<".$self->{wordnet_dir}."/$data_file[$i]";
	die "Not able to open ".$self->{wordnet_dir}."/$data_file[$i]: $!\n"
	    if (!defined ($self->{data_fh}->[$i]));
    }
}


# Remove duplicate values from an array, which must be passed as a
# reference to an array.
sub remove_duplicates
{
    my $self = shift;
    my $aref = shift;   # Array reference

    my $i = 0;
    while ( $i < $#$aref ) {
        if ( grep {$_ eq ${$aref}[$i]} @{$aref}[$i+1 .. $#$aref] ) {
            # element at $i is duplicate--remove it
            splice @$aref, $i, 1;
        } else {
            $i++;
        }
    }
}


# Generate list of all possible forms of how word may be found in WordNet
sub forms
{
    my ($self, $string) = @_;
    my ($i, $j);

    # The query string (word, pos and sense #)
    my ($word, $pos, $sense) = $string =~ /^([^\#]+)(?:\#([^\#]+)(?:\#(\d+))?)?$/; 
    warn "Sense number is ignored in calls to 'forms'\n" if defined $sense;
    print STDERR "forms: WORD=$word POS=$pos\n" if ($self->{verbose});

    die "QueryData: \"$pos\" not a legal part of speech!\n"
	if (!defined ($pos_num{$pos}));
    $pos = $pos_num{$pos};

    # Canonicalize word
    $word = lower ($word);

    my @token = split (/\s+/, $word);
    my @token_form;

    # Find all possible forms for all tokens
    for ($i=0; $i < @token; $i++)
    {
	# always include word as it appears in original 'forms' query
	push @{$token_form[$i]}, $token[$i];
	# also include entry from morphological exceptions, if it exists
	push @{$token_form[$i]}, $self->{morph_exc}->[$pos]->{$token[$i]} if (defined ($self->{morph_exc}->[$pos]->{$token[$i]}));

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
        # Remove any form generated more than once by the above code 
        # (This usually happens when an exception can also be generated.) 
        $self->remove_duplicates($token_form[$i]);
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

    # finally, add exception entry for entire collocation if query
    # word has more than one segment/token and an exception entry exists
    push @word_form, $self->{morph_exc}->[$pos]->{$word}
        if (@token > 1 and (defined ($self->{morph_exc}->[$pos]->{$word}))); 
    print STDERR "Word_form array= @word_form\n" if ($self->{verbose});
    return @word_form;
}


# Given a line from data.pos, store pointer relations in %{$pointer}
sub get_pointers
{
    my ($line, $pointer, $index_offset) = @_;
    my $i;

    my ($offset, $lex_file, $ss_type, $w_cnt, @stuff) = split (/\s+/, $line);
    # $w_cnt is in hex, not decimal
    $w_cnt = hex ($w_cnt);
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
    my ($offset, $w_cnt, @stuff);
    ($offset, undef, undef, $w_cnt, @stuff) = split (/\s+/);
    # $w_cnt is in hex, not decimal
    $w_cnt = hex ($w_cnt);
    print STDERR "Offsets differ INDEX=$index_offset DATA=$offset\n"
	if ($index_offset != $offset);
    # Grab words
    my (@words) = splice @stuff, 0, $w_cnt*2;
    # Get rid of lex file number junk
    for ($i=1; $i <= $w_cnt; $i++) { splice @words, $i, 1; }
    foreach my $word (@words)
    {
	$word = lower ($word);
	# Eliminate syntactic marker (if any)
        $word =~ s/\(.*\)$//; 
	my @offset_array = (unpack "i*", $self->{"index"}->[$pos_num{$pos}]->{$word});
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
    my ($offset, $word);
    ($offset, undef, undef, undef, $word) = split (/\s+/);
    $word = lower ($word);
    # Eliminate syntactic marker (if any)
    $word =~ s/\(.*\)$//; 
    print STDERR "Offsets differ INDEX=$index_offset DATA=$offset\n"
	if ($index_offset != $offset);
    my @offset_array = (unpack "i*", $self->{"index"}->[$pos_num{$pos}]->{$word});
    for ($i=0; $i < @offset_array; $i++)
    {
	return "$word\#$pos\#".($i+1) if ($offset_array[$i] == $index_offset);
    }
}


# Return the WordNet data file offset for a fully qualified word sense
sub offset
{
    my $self = shift;
    # The query string (word, pos and sense #)
    my $string = shift;

    # get word, pos, and sense from second argument:
    my ($word, $pos, $sense) = $string =~ /^([^\#]+)(?:\#([^\#]+)(?:\#(\d+))?)?$/; 
    
    print STDERR "offset: WORD=$word POS=$pos SENSE=$sense\n"
	if ($self->{verbose});
    if (!defined($sense) or !defined($pos) or !defined($word) 
	or !defined($pos_num{$pos}))
    {
	warn "Bad query string: $string.  I need a fully qualified sense (WORD#POS#SENSE)\n";
	return;
    }

    $word = lower ($word) if ($word);

    # Data file pointer
    return (unpack "i*", $self->{"index"}->[$pos_num{$pos}]->{$word})[$sense-1];
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

    # Ensure that input record separator is "\n"
    my $old_separator = $/;
    $/ = "\n";

    # get word, pos, and sense from second argument:
    my ($word, $pos, $sense) = $string =~ /^([^\#]+)(?:\#([^\#]+)(?:\#(\d+))?)?$/; 

    $word = lower ($word) if ($word);
    warn "query: Illegal Part-of-speech: POS=$pos WORD=$word\n" 
	if ($pos && !$pos_num{$pos});

    if ($sense)
    {
	print STDERR "query: WORD=$word POS=$pos SENSE=$sense RELATION=$relation\n" if ($self->{verbose});

	if (!$relation)
	{
	    warn "Second argument is not a valid relation: $relation\n";
	    return ();
	}
	# Map to abbreviation if relation name is in long or symbol form
	$relation = $relation_sym{$relation} if ($relation_sym{$relation});

	my $fh = $self->{data_fh}->[$pos_num{$pos}];
	# Each entry should be an array reference.  Each element in the
	# array should be a pos-qualified offset (OFFSET#POS)
	my %pointer;
	# Sense number can be obtained from offset pointer ordering in index.*

	# Data file pointer
	my $index_offset =
	    (unpack "i*", $self->{"index"}->[$pos_num{$pos}]->{$word})[$sense-1];
	seek $fh, $index_offset, 0;
	# Get line corresponding to sense
	$_ = <$fh>;

	if ($relation eq "glos")
	{
	    m/.*\|\s*(.*)$/;
	    return $1;
	}

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
	    warn "No such relation ($relation) for word \'$word\'\n"
		if ($self->{verbose});
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
    elsif ($pos)
    {
	print STDERR "query: WORD=$word POS=$pos\n" if ($self->{verbose});

	my (@rtn, $i);
	my @pointers = unpack "i*", $self->{"index"}->[$pos_num{$pos}]->{$word}
	    if defined $self->{"index"}->[$pos_num{$pos}]->{$word};
	my $sense_cnt = scalar @pointers;
	for ($i=0; $i < @pointers; $i++) {
	    push @rtn, "$string\#".($i+1);
	}
	return @rtn;
    }
    elsif ($word)
    {
	print STDERR "query: WORD=$word\n" if ($self->{verbose});
	my ($i, @rtn);
	for ($i=1; $i <= 4; $i++)
	{
	    push @rtn, "$word\#".$pos_map{$i}
	      if ($self->{"index"}->[$i]->{$word});
	}
	return @rtn;
    }
    else
    {
	warn "Illegal query string: $string\n";
    }
    # Return setting of input record separator
    $/ = $old_separator;
}

sub valid_forms
{
    my ($self, $string) = @_;
    my (@possible_forms, @valid_forms);
    
    # get word, pos, and sense from second argument:
    my ($word, $pos, $sense) = $string =~ /^([^\#]+)(?:\#([^\#]+)(?:\#(\d+))?)?$/; 
    warn "Sense number is ignored in calls to 'valid_forms'\n"
	if (defined $sense);
    die "Part of speech is required in call to 'valid_forms'\n"
	if (! defined $pos);
    
    @possible_forms = $self->forms ("$word#$pos");
    @valid_forms = grep $self->query ("$_#$pos"), @possible_forms;

    return @valid_forms;
}

# List all words in WordNet database of a particular part of speech
sub list_all_words
{
    my ($self, $pos) = @_;
    return keys(%{$self->{"index"}->[$pos_num{$pos}]})
}

# Return length of (some) path to root, plus one (root is considered
# to be level 1)
sub level
{
    my ($self, $word) = @_;
    my $level;

    for ($level=0; $word; $level++)
    {
	($word) = $self->query ($word, "hype");
    }
    return $level;
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

  # Load index, mophological exclusion files (time-consuming process)
  my $wn = WordNet::QueryData->new ("/usr/local/dict", 1);

  # Synset of cat, sense #7
  print "Cat#7-> ", join (", ", $wn->query ("cat#n#7", "syns")), "\n";

  # Hyponyms of cat, sense #1 (house cat)
  print "Cat#1-> ", join (", ", $wn->query ("cat#n#1", "hypo")), "\n";

  # Senses of run as a verb
  print "Run->", join (", ", $wn->query ("run#v")), "\n";

  # Base form(s) of the verb 'lay down'
  print "lay down-> ", join (", ", $wn->valid_forms ("lay down#v")), "\n";

  # Print number of nouns in WordNet
  print "Count of nouns: ", scalar($wn->list_all_words("noun")), "\n";

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
work on making this a less demanding step.  However, once the index
and morph. exc. files are loaded, queries are very fast.

=head1 USAGE

To use the WordNet::QueryData module, incorporate the package with
"use WordNet::QueryData;".  Then, establish an instance of the package
with "my $wn = new WordNet::QueryData ("/usr/local/dict");".  If the
WordNet dict is not located in /usr/local/dict on your system, pass
the correct directory as the first argument of the function call.  You
may pass a second argument of 1 if you wish the module to print out
progress and verbose error messages.

WordNet::QueryData is object-oriented.  You can establish multiple
instances simply by using 'new' multiple times, however, the only
practical use I can see for this is comparing data from different
WordNet versions.  I did the module OO-style because I had never done
an OO perl module, figured it was time to learn and thought it might
make the code a bit cleaner.

The WordNet::QueryData object has two object functions that you might
want to use, 'valid_forms' and 'query'.  'query' gives you direct
access to the large set of WordNet relations.  It accepts a query
string and a relation.  The query string may be at one of three
specification levels:

  1) WORD (e.g. dog)
  2) WORD#POS (e.g. house#noun)
  3) WORD#POS#SENSE (e.g. ghostly#adj#1)

WORD is simply an english word.  Spaces should be used to separate
tokens (not underscores as is used in the WordNet database).  Case
does not matter.  In order to get a meaningful result, the word must
exactly match one of the words in the WordNet database files.  Use
'valid_forms' to determine the form in which WordNet stores the word.

POS is the part of speech.  Use 'n' for noun, 'v' for verb, 'a' for
adjective and 'r' for adverb.  You may also use full names and some
abbreviations (as above and in test.pl).  POS is optional for calls to
'query', and required for calls to 'valid_forms'.  SENSE is a number
that uniquely identifies the word sense.  You can 'query' using a
WORD#POS form to get a list of the word's senses for that part of
speech.

Executing 'query' with only a WORD will return a list of WORD#POS
strings.  Passing 'query' a WORD#POS will return a list of
WORD#POS#SENSE strings.  'query' calls of these forms do not return
any information about WordNet relations pertaining to WORD.  The third
format, WORD#POS#SENSE, requires a second argument, RELATION, which
may be any of the strings used by WordNet to designate a relation.
Here is a list of most (if not all) of them:

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
  glos - word definition

Such queries return a list of corresponding strings in the
WORD#POS#SENSE format.  In the case of 'syns', one string is returned
for each word that is part of the synset.  For other relations, one
WORD#POS#SENSE string is returned for each synset (you can map 'syns'
on to the returned array to get a full list of the words for a
relation).  In the case of relations like 'hype' and 'hypo', query
returns only the immediate hypernyms or hyponyms.  You can use 'query'
recursively to get a full hyper/hyponym tree.

While 'query' requires that WORD exactly matches an entry in WordNet,
QueryData has functionality for determining the WordNet baseforms to
which a particular WORD may correpsond.  This functionality is
encapsulated in 'valid_forms'.  After suppling 'valid_forms' with
QUERY, a string in the form WORD#POS, 'valid_forms' will return a list
of WORD#POS strings which are existing WordNet entries that are base
forms of QUERY.  Normally, one string will be returned.  An empty list
will be returned if QUERY is not a word that WordNet knows about.

QueryData also has functionality for retrieving WordNet datafile
offsets (the unique number that identifies a word sense).  The
function 'offset' accepts a fully-qualified word sense in the form
WORD#POS#SENSE and returns the corresponding numerical offset.  See
WordNet documentation for more information about this quantity.

The function 'list_all_words' will return an array of all words of a
particular part-of-speech given that part-of-speech as its only
argument.

=head1 NOTES

Requires access to WordNet database files (data.noun, index.noun, etc.)

=head1 COPYRIGHT

Copyright 2000 Jason Rennie <jrennie@ai.mit.edu>  All rights reserved.

This module is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 SEE ALSO

perl(1)

http://www.cogsci.princeton.edu/~wn/

http://www.ai.mit.edu/~jrennie/WordNet/

=cut
