# -*- perl -*-
#
# Package to interface with WordNet (wn) command line program
# written by Jason Rennie <jrennie@mitre.org>, July 1999

# Run 'perldoc' on this file to produce documentation

# Copyright 1999 Jason Rennie <jrennie@ai.mit.edu>

# This module is free software; you can redistribute it and/or modify
# it under the same terms as Perl itself.

# $Id: QueryData.pm,v 1.17 2002/04/08 04:39:06 jrennie Exp $

####### manual page & loadIndex ##########

# STANDARDS
# =========
# - upper case to distinguish words in function & variable names
# - use 'warn' to report warning & progress messages
# - begin 'warn' messages with "(fn)" where "fn" is function name
# - all non-trivial function calls should receive $self
# - we ignore syntactic markers

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
    $VERSION = do { my @r=(q$Revision: 1.17 $=~/\d+/g); sprintf "%d."."%02d"x$#r,@r };
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
my %relNameSym = ('ants' => {'!'=>1},
		  'hype' => {'@'=>1},
		  'hypo' => {'~'=>1},
		  'mmem' => {'%m'=>1},
		  'msub' => {'%s'=>1},
		  'mprt' => {'%p'=>1},
		  'mero' => {'%m'=>1, '%s'=>1, '%p'=>1},
		  'hmem' => {'#m'=>1},
		  'hsub' => {'#s'=>1},
		  'hprt' => {'#p'=>1},
		  'holo' => {'#m'=>1, '#s'=>1, '#p'=>1},
		  'attr' => {'='=>1},
		  'enta' => {'*'=>1},
		  'caus' => {'>'=>1},
		  'also' => {'^'=>1},
		  'vgrp' => {'$'=>1}, # '$' Hack for font-lock in emacs
		  'sim' => {'&'=>1},
		  'part' => {'<'=>1},
		  'pert' => {'\\'=>1});

# Mapping from WordNet symbols to short relation names
my %relSymName = ('!'  => 'ants',
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

# DEPRECATED!  DO NOT USE!  Use relSymName instead.
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

# WordNet data file names
my @excFile = ("", "noun.exc", "verb.exc", "adj.exc", "adv.exc");
my @indexFileUnix = ("", "index.noun", "index.verb", "index.adj", "index.adv");
my @dataFileUnix = ("", "data.noun", "data.verb", "data.adj", "data.adv");
my @indexFilePC = ("", "noun.idx", "verb.idx", "adj.idx", "adv.idx");
my @dataFilePC = ("", "noun.dat", "verb.dat", "adj.dat", "adv.dat");

my $wnHomeUnix = defined($ENV{"WNHOME"}) ? $ENV{"WNHOME"} : "/usr/local/wordnet1.7";
my $wnHomePC = defined($ENV{"WNHOME"}) ? $ENV{"WNHOME"} : "C:\\wn17";
my $wnPrefixUnix = defined($ENV{"WNSEARCHDIR"}) ? $wnHomeUnix."/".$ENV{"WNSEARCHDIR"} : "$wnHomeUnix/dict";
my $wnPrefixPC = defined($ENV{"WNSEARCHDIR"}) ? $wnHomePC."\\".$ENV{"WNSEARCHDIR"} : "$wnHomePC\\dict";

# WordNet database version
my $version;

END { } # module clean-up code here (global destructor)

###############
# Subroutines #
###############

# report WordNet version
sub version { return $version; }

# convert to lower case, translate '_' to ' ' and eliminate any
# syntactic marker
sub lower#
{ 
    my $word = shift;
    $word =~ tr/A-Z_/a-z /;
    $word =~ s/\(.*\)$//;
    return $word;
}

# Perform all initialization for new WordNet class instance
sub _initialize#
{
    my $self = shift;
    warn "Loading WordNet data...\n" if ($self->{verbose});
    # Ensure that input record separator is "\n"
    my $old_separator = $/;
    $/ = "\n";
    
    # Load morphology exclusion mapping
    $self->loadExclusions ();
    $self->loadIndex ();
    $self->openData ();
    warn "Done.\n" if ($self->{verbose});
    
    # Return setting of input record separator
    $/ = $old_separator;
}

sub new#
{
    # First argument is class
    my $class = shift;
    # Second is location of WordNet dictionary; Third is verbosity
    
    my $self = {};
    bless $self, $class;
    $self->{dir} = shift if (defined(@_ > 0));
    $self->{verbose} = @_ ? shift : 0;
    warn "Dir = ", $self->{dir}, "\n" if ($self->{verbose});
    warn "Verbose = ", $self->{verbose}, "\n" if ($self->{verbose});
    $self->_initialize ();
    return $self;
}

# Object destructor
sub DESTROY#
{
    my $self = shift;
    
    for (my $i=1; $i <= 4; $i++) {
	undef $self->{data_fh}->[$i];
    }
}

# Load mapping to non-standard canonical form of words (morphological
# exceptions)
sub loadExclusions#
{
    my $self = shift;
    warn "(loadExclusions)" if ($self->{verbose});

    for (my $i=1; $i <= 4; $i++)
    {
	my $fileUnix = defined($self->{dir}) ? $self->{dir}."/".$excFile[$i] : "$wnPrefixUnix/$excFile[$i]";
	my $filePC = defined($self->{dir}) ? $self->{dir}."\\".$excFile[$i] : "$wnPrefixPC\\$excFile[$i]";
	
	my $fh = new FileHandle($fileUnix);
	$fh = new FileHandle($filePC) if (!defined($fh));
	die "Not able to open $fileUnix or $filePC: $!" if (!defined($fh));
	
	while (my $line = <$fh>)
	{
	    my ($exc, @word) = split(/\s+/, $line);
	    next if (!@word);
	    $exc = lower ($exc);
	    for (my $i=0; $i < @word; ++$i) {
		$word[$i] = lower($word[$i]);
	    }
	    @{$self->{morph_exc}->[$i]->{$exc}} = @word;
	}
    }
}

sub loadIndex#
{
    my $self = shift;
    warn "(loadIndex)" if ($self->{verbose});

    for (my $i=1; $i <= 4; $i++)
    {
	my $fileUnix = defined($self->{dir}) ? $self->{dir}."/".$indexFileUnix[$i] : "$wnPrefixUnix/$indexFileUnix[$i]";
	my $filePC = defined($self->{dir}) ? $self->{dir}."\\".$indexFilePC[$i] : "$wnPrefixPC\\$indexFilePC[$i]";
	
	my $fh = new FileHandle($fileUnix);
	$fh = new FileHandle($filePC) if (!defined($fh));
	die "Not able to open $fileUnix or $filePC: $!" if (!defined($fh));
	
	my $line;
	while ($line = <$fh>) {
	    $version = $1 if (!defined($version) and $line =~ m/WordNet (\d+\.\d+)/);
	    last if ($line =~ m/^\S/);
	}
	while (1) {
	    my ($lemma, $pos, $sense_cnt, $p_cnt);
	    ($lemma, $pos, $sense_cnt, $p_cnt, $line) = split(/\s+/, $line, 5);
	    $lemma = lower($lemma);
	    for (my $i=0; $i < $p_cnt; ++$i) {
		(undef, $line) = split(/\s+/, $line, 2);
	    }
	    my (undef, undef, @offset) = split(/\s+/, $line);
	    $self->{"index"}->[$pos_num{$pos}]->{$lemma} = pack "i*", @offset;
	    $line = <$fh>;
	    last if (!$line);
	}
    }
}

# Open data files and return file handles
sub openData#
{
    my $self = shift;
    warn "(openData)" if ($self->{verbose});

    for (my $i=1; $i <= 4; $i++)
    {
	my $fileUnix = defined($self->{dir}) ? $self->{dir}."/".$dataFileUnix[$i] : "$wnPrefixUnix/$dataFileUnix[$i]";
	my $filePC = defined($self->{dir}) ? $self->{dir}."\\".$dataFilePC[$i] : "$wnPrefixPC\\$dataFilePC[$i]";
	
	my $fh = new FileHandle($fileUnix);
	$fh = new FileHandle($filePC) if (!defined($fh));
	die "Not able to open $fileUnix or $filePC: $!" if (!defined($fh));
	$self->{data_fh}->[$i] = $fh;
    }
}

# DEPRECATED!  DO NOT USE!  Use removeDuplicates instead.
sub remove_duplicates
{
    my ($self, $aref) = @_;
    $self->removeDuplicates($aref);
}

# Remove duplicate values from an array, which must be passed as a
# reference to an array.
sub removeDuplicates
{
    my ($self, $aref) = @_;
    warn "(removeDupliates) array=", join(" ", @{$aref}), "\n"
	if ($self->{verbose});
    
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
sub forms#
{
    my ($self, $string) = @_;
    
    # The query string (word, pos and sense #)
    my ($word, $pos, $sense) = $string =~ /^([^\#]+)(?:\#([^\#]+)(?:\#(\d+))?)?$/; 
    warn "(forms) Sense number ignored\n" if (defined($sense));
    warn "(forms) WORD=$word POS=$pos\n" if ($self->{verbose});
    die "(forms) Bad part-of-speech: $pos" if (!defined($pos_num{$pos}));
    $pos = $pos_num{$pos};
    $word = lower ($word);
    
    my @token = split (/\s+/, $word);
    my @token_form;
    
    # Find all possible forms for all tokens
    for (my $i=0; $i < @token; $i++)
    {
	# include original form and morph. exceptions
	push @{$token_form[$i]}, $token[$i];
	push @{$token_form[$i]}, @{$self->{morph_exc}->[$pos]->{$token[$i]}} if (defined ($self->{morph_exc}->[$pos]->{$token[$i]}));
	
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
        $self->remove_duplicates($token_form[$i]);
    }
    
    # Generate all possible token sequences (collocations)
    my @index; for (my $i=0; $i < @token; $i++) { $index[$i] = 0; }
    my @word_form;
    while (1) {
	my $this_word;
	# String together one sequence of possibilities
	for (my $i=0; $i < @token; $i++) {
	    $this_word .= " ".$token_form[$i]->[$index[$i]]
		if (defined($this_word));
	    $this_word = $token_form[$i]->[$index[$i]]
		if (!defined($this_word));
	}
	push @word_form, $this_word;
	
	# Increment counter
	my $i;
	for ($i=0; $i < @token; $i++) {
	    $index[$i]++;
	    # Exit loop if we don't need to increment next index
	    last if ($index[$i] < @{$token_form[$i]});
	    # Otherwise, reset this value, increment next index
	    $index[$i] = 0;
	}
	# If we had to reset every index, we have tried all possibilities
	last if ($i >= @token);
    }
    push @word_form, @{$self->{morph_exc}->[$pos]->{$word}}
    if (@token > 1 and (defined ($self->{morph_exc}->[$pos]->{$word}))); 
    return @word_form;
}

# DEPRECATED!  DO NOT USE!  Use "getSensePointers" instead.
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

# $line is line from data file; $ptr is a reference to a hash of
# symbols; returns list of word#pos#sense strings
sub getSensePointers#
{
    my ($self, $line, $ptr) = @_;
    warn "(getSensePointers) ptr=", keys(%{$ptr}), " line=\"$line\"\n"
	if ($self->{verbose});
    
    my (@rtn, $w_cnt);
    (undef, undef, undef, $w_cnt, $line) = split (/\s+/, $line, 5);
    $w_cnt = hex ($w_cnt);
    for (my $i=0; $i < $w_cnt; ++$i) {
	(undef, undef, $line) = split(/\s+/, $line, 3);
    }
    my $p_cnt;
    ($p_cnt, $line) = split(/\s+/, $line, 2);
    for (my $i=0; $i < $p_cnt; ++$i) {
	my ($sym, $offset, $pos, $st);
	($sym, $offset, $pos, $st, $line) = split(/\s+/, $line, 5);
	push @rtn, $self->getSense($offset, $pos)
	    if ($st==0 and defined($ptr->{$sym}));
    }
    return @rtn;
}

# $line is line from data file; $ptr is a reference to a hash of
# sybols; $word is query word/lemma; returns list of word#pos strings
sub getWordPointers#
{
    my ($self, $line, $ptr, $word) = @_;
    warn "(getWordPointers) ptr=", keys(%{$ptr}), " word=$word line=\"$line\"\n"
	if ($self->{verbose});
    
    my (@rtn, $w_cnt);
    (undef, undef, undef, $w_cnt, $line) = split (/\s+/, $line, 5);
    $w_cnt = hex ($w_cnt);
    my @word;
    for (my $i=0; $i < $w_cnt; ++$i) {
	($word[$i], undef, $line) = split(/\s+/, $line, 3);
    }
    my $p_cnt;
    ($p_cnt, $line) = split(/\s+/, $line, 2);
    for (my $i=0; $i < $p_cnt; ++$i) {
	my ($sym, $offset, $pos, $st);
	($sym, $offset, $pos, $st, $line) = split(/\s+/, $line, 5);
	next if (!$st);
	my ($src, $tgt) = ($st =~ m/(\d{2})(\d{2})/);
	push @rtn, $self->getWord($offset, $pos, $tgt)
	    if (defined($ptr->{$sym}) and ($word eq $word[$src-1]));
    }
    return @rtn;
}

# DEPRECATED!  DO NOT USE!  Use "getAllSenses" instead.
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

# DEPRECATED!  DO NOT USE!  Use "getSense" instead.
sub get_word
{
    my ($self, $index_offset, $pos) = @_;
    
    warn "(get_word) offset=$index_offset pos=$pos\n" if ($self->{verbose});
    my $fh = $self->{data_fh}->[$pos_num{$pos}];
    seek $fh, $index_offset, 0;
    $_ = <$fh>;
    my ($offset, $word);
    ($offset, undef, undef, undef, $word) = split (/\s+/);
    $word = lower ($word);
    print STDERR "Offsets differ INDEX=$index_offset DATA=$offset\n"
	if ($index_offset != $offset);
    my @offset_array = (unpack "i*", $self->{"index"}->[$pos_num{$pos}]->{$word});
    for (my $i=0; $i < @offset_array; $i++)
    {
	return "$word\#$pos\#".($i+1) if ($offset_array[$i] == $index_offset);
    }
}

# return list of word#pos#sense for $offset and $pos (synset)
sub getAllSenses#
{
    my ($self, $offset, $pos) = @_;
    warn "(getAllSenses) offset=$offset pos=$pos\n" if ($self->{verbose});

    my @rtn;
    my $fh = $self->{data_fh}->[$pos_num{$pos}];
    seek $fh, $offset, 0;
    my $line = <$fh>;
    my $w_cnt;
    (undef, undef, undef, $w_cnt, $line) = split(/\s+/, $line, 5);
    $w_cnt = hex ($w_cnt);
    my @words;
    for (my $i=0; $i < $w_cnt; ++$i) {
	($words[$i], undef, $line) = split(/\s+/, $line, 3);
    }
    foreach my $word (@words) {
	$word = lower ($word);
	my @offArr = (unpack "i*", $self->{"index"}->[$pos_num{$pos}]->{$word});
	for (my $i=0; $i < @offArr; $i++) {
	    if ($offArr[$i] == $offset) {
		push @rtn, "$word\#$pos\#".($i+1);
		last;
	    }
	}
    }
    return @rtn;
}

# returns word#pos#sense for given offset and pos
sub getSense#
{
    my ($self, $offset, $pos) = @_;
    warn "(getSense) offset=$offset pos=$pos\n" if ($self->{verbose});
    
    my $fh = $self->{data_fh}->[$pos_num{$pos}];
    seek $fh, $offset, 0;
    my $line = <$fh>;
    my ($word);
    (undef, undef, undef, undef, $word, $line) = split (/\s+/, $line, 6);
    $word = lower($word);
    my @offArr = (unpack "i*", $self->{"index"}->[$pos_num{$pos}]->{$word});
    for (my $i=0; $i < @offArr; $i++) {
	return "$word\#$pos\#".($i+1) if ($offArr[$i] == $offset);
    }
    die "(getSense) Internal error: offset=$offset pos=$pos";
}

# returns word#pos for given offset, pos and number
sub getWord#
{
    my ($self, $offset, $pos, $num) = @_;
    warn "(getWord) offset=$offset pos=$pos num=$num" if ($self->{verbose});
    
    my $fh = $self->{data_fh}->[$pos_num{$pos}];
    seek $fh, $offset, 0;
    my $line = <$fh>;
    my $w_cnt;
    (undef, undef, undef, $w_cnt, $line) = split (/\s+/, $line, 5);
    for (my $i=0; $i < $w_cnt; ++$i) {
	my $word;
	($word, undef, $line) = split(/\s+/, $line, 3);
	return "$word\#$pos" if ($i+1 == $num);
    }
    die "(getWord) Bad number: offset=$offset pos=$pos num=$num";
}


# Return the WordNet data file offset for a fully qualified word sense
sub offset#
{
    my ($self, $string) = @_;

    my ($word, $pos, $sense) = $string =~ /^([^\#]+)(?:\#([^\#]+)(?:\#(\d+))?)?$/; 
    warn "(offset) WORD=$word POS=$pos SENSE=$sense\n" if ($self->{verbose});
    die "(offset) Bad query string: $string"
	if (!defined($sense) or !defined($pos)
	    or !defined($word) or !defined($pos_num{$pos}));
    $word = lower ($word);
    return (unpack "i*", $self->{"index"}->[$pos_num{$pos}]->{$word})[$sense-1];
}

# DEPRECATED!  DO NOT USE!  Use "querySense" instead.
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
    warn "(query) Illegal Part-of-speech: POS=$pos WORD=$word\n" 
	if ($pos && !$pos_num{$pos});
    
    if ($sense)
    {
	print STDERR "(query) WORD=$word POS=$pos SENSE=$sense RELATION=$relation\n" if ($self->{verbose});
	
	if (!$relation)
	{
	    warn "Second argument is not a valid relation: $relation\n";
	    return ();
	}
	# Map to abbreviation if relation name is in long or symbol form
	$relation = $relSymName{$relation} if ($relSymName{$relation});
	
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
	print STDERR "(query) WORD=$word POS=$pos\n" if ($self->{verbose});
	
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
	print STDERR "(query) WORD=$word\n" if ($self->{verbose});
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

sub querySense#
{
    my $self = shift;
    my $string = shift;
    
    # Ensure that input record separator is "\n"
    my $old_separator = $/;
    $/ = "\n";
    my @rtn;
    
    # get word, pos, and sense from second argument:
    my ($word, $pos, $sense) = $string =~ /^([^\#]+)(?:\#([^\#]+)(?:\#(\d+))?)?$/; 
    die "(querySense) Bad query string: $string" if (!defined($word));
    $word = lower ($word);
    die "(querySense) Bad part-of-speech: $string"
	if (defined($pos) && !$pos_num{$pos});
    
    if (defined($sense)) {
	my $rel = shift;
	warn "(querySense) WORD=$word POS=$pos SENSE=$sense RELATION=$rel\n" if ($self->{verbose});
	die "(querySense) Relation required: $string" if (!defined($rel));
	die "(querySense) Bad relation: $rel" 
	    if (!defined($relNameSym{$rel}) and !defined($relSymName{$rel})
		 and ($rel ne "glos") and ($rel ne "syns"));
	$rel = $relSymName{$rel} if (defined($relSymName{$rel}));
	
	my $fh = $self->{data_fh}->[$pos_num{$pos}];
	my $offset = (unpack "i*", $self->{"index"}->[$pos_num{$pos}]->{$word})[$sense-1];
	seek $fh, $offset, 0;
	my $line = <$fh>;
	
	if ($rel eq "glos") {
	    m/.*\|\s*(.*)$/;
	    $rtn[0] = $1;
	} elsif ($rel eq "syns") {
	    @rtn = $self->getAllSenses ($offset, $pos);
	} else {
	    @rtn = $self->getSensePointers($line, $relNameSym{$rel});
	}
    } elsif (defined($pos)) {
	warn "(querySense) WORD=$word POS=$pos\n" if ($self->{verbose});
	if (defined($self->{"index"}->[$pos_num{$pos}]->{$word})) {
	    my @offset = unpack "i*", $self->{"index"}->[$pos_num{$pos}]->{$word};
	    for (my $i=0; $i < @offset; $i++) {
		push @rtn, "$string\#".($i+1);
	    }
	}
    } elsif (defined($word)) {
	print STDERR "(querySense) WORD=$word\n" if ($self->{verbose});
	for (my $i=1; $i <= 4; $i++) {
	    push @rtn, "$word\#".$pos_map{$i}
	    if ($self->{"index"}->[$i]->{$word});
	}
    }
    # Return setting of input record separator
    $/ = $old_separator;
    return @rtn;
}

sub queryWord#
{
    my $self = shift;
    my $string = shift;
    
    # Ensure that input record separator is "\n"
    my $old_separator = $/;
    $/ = "\n";
    my @rtn;
    
    # get word, pos, and sense from second argument:
    my ($word, $pos, $sense) = $string =~ /^([^\#]+)(?:\#([^\#]+)(?:\#(\d+))?)?$/; 
    warn "(queryWord) Ignorning sense: $string" if (defined($sense));
    die "(queryWord) Bad query string: $string" if (!defined($word));
    $word = lower ($word);
    die "(queryWord) Bad part-of-speech: $string"
	if (defined($pos) && !$pos_num{$pos});
    
    if (defined($pos)) {
	my $rel = shift;
	warn "(queryWord) WORD=$word POS=$pos RELATION=$rel\n" if ($self->{verbose});
	die "(queryWord) Relation required: $string" if (!defined($rel));
	die "(queryWord) Bad relation: $rel" 
	    if ((!defined($relNameSym{$rel}) and !defined($relSymName{$rel})));
	$rel = $relSymName{$rel} if (defined($relSymName{$rel}));
	
	my $fh = $self->{data_fh}->[$pos_num{$pos}];
	my @offsets = unpack "i*", $self->{"index"}->[$pos_num{$pos}]->{$word};
	foreach my $offset (@offsets) {
	    seek $fh, $offset, 0;
	    my $line = <$fh>;
	    push @rtn, $self->getWordPointers($line, $relNameSym{$rel}, $word);
	}
    } elsif (defined($word)) {
	print STDERR "(queryWord) WORD=$word\n" if ($self->{verbose});
	for (my $i=1; $i <= 4; $i++) {
	    push @rtn, "$word\#".$pos_map{$i}
	    if ($self->{"index"}->[$i]->{$word});
	}
    }
    # Return setting of input record separator
    $/ = $old_separator;
    return @rtn;
}

# DEPRECATED!  DO NOT USE!  Use validForms instead.
sub valid_forms
{
    my ($self, $string) = @_;
    return $self->validForms($string);
}

# return list of entries in wordnet database (in word#pos form)
sub validForms#
{
    my ($self, $string) = @_;
    my (@possible_forms, @valid_forms);
    
    # get word, pos, and sense from second argument:
    my ($word, $pos, $sense) = $string =~ /^([^\#]+)(?:\#([^\#]+)(?:\#(\d+))?)?$/; 
    warn "(valid_forms) Sense number ignored: $string\n" if (defined $sense);
    die "(valid_forms) Bad part of speech: $string"
	if (!defined($pos_map{$pos}));
    
    @possible_forms = $self->forms ("$word#$pos");
    @valid_forms = grep $self->querySense ("$_#$pos"), @possible_forms;
    
    return @valid_forms;
}

# DEPRECATED!  DO NOT USE!  Use listAllWords instead.
sub list_all_words
{
    my ($self, $pos) = @_;
    return $self->listAllWords($pos);
}

# List all words in WordNet database of a particular part of speech
sub listAllWords#
{
    my ($self, $pos) = @_;
    return keys(%{$self->{"index"}->[$pos_num{$pos}]});
}

# Return length of (some) path to root, plus one (root is considered
# to be level 1); $word must be word#pos#sense form
sub level#
{
    my ($self, $word) = @_;
    my $level;
    
    for ($level=0; $word; ++$level)
    {
	($word) = $self->querySense ($word, "hype");
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

  my $wn = WordNet::QueryData->new;

  print "Synset: ", join(", ", $wn->querySense("cat#n#7", "syns")), "\n";
  print "Hyponyms: ", join(", ", $wn->querySense("cat#n#1", "hypo")), "\n";
  print "Parts of Speech: ", join(", ", $wn->querySense("run")), "\n";
  print "Senses: ", join(", ", $wn->querySense("run#v")), "\n";
  print "Forms: ", join(", ", $wn->validForms("lay down#v")), "\n";
  print "Noun count: ", scalar($wn->listAllWords("noun")), "\n";
  print "Antonyms: ", join(", ", $wn->queryWord("affirm#v")), "\n";

=head1 DESCRIPTION

WordNet::QueryData provides a direct interface to the WordNet database
files.  It requires the WordNet package
(http://www.cogsci.princeton.edu/~wn/).  It allows the user direct
access to the full WordNet semantic lexicon.  All parts of speech are
supported and access is generally very efficient because the index and
morphical exclusion tables are loaded at initialization.  This
initialization step is slow (appx. 10-15 seconds), but queries are
very fast thereafter---thousands of queries can be completed every
second.

=head1 USAGE

=head2 LOCATING THE WORDNET DATABASE

To use QueryData, you must tell it where your WordNet database is.
There are two ways you can do this: 1) by setting the appropriate
environment variables, or 2) by passing the location to QueryData when
you invoke the "new" function.

QueryData knows about two environment variables, WNHOME and
WNSEARCHDIR.  By default, QueryData assumes that WordNet data files
are located in WNHOME/WNSEARCHDIR (WNHOME\WNSEARCHDIR on PC), where
WNHOME defaults to "/usr/local/wordnet1.7" on Unix and "C:\wn17" on
PC.  WNSEARCHDIR defaults to "dict".  Normally, all you have to do is
to set the WNHOME variable to the location where you unpacked your
WordNet distribution.  The database files are always unpacked to the
"dict" subdirectory.

You can also pass the location of the database files directly to
QueryData.  To do this, pass the location to "new":

  my $wn = new WordNet::QueryData->new("/usr/local/wn17/dict")

When calling "new" in this fashion, you can give it a second argument
to have QueryData print out progress and warning messages.

=head2 QUERYING THE DATABASE

There are two primary query functions, 'querySense' and 'queryWord'.
querySense accesses relations between senses; queryWord accesses
relations between words.  Most relations (including hypernym, hyponym,
meronym, holonym) are between senses.  Those between words include
"also see", antonym, pertainym and "participle of verb."  The glossary
definition of a sense and the words in a synset are obtained via
querySense.

Both functions take as their first argument a query string that takes
one of three forms:

  (1) word (e.g. "dog")
  (2) word#pos (e.g. "house#n")
  (3) word#pos#sense (e.g. "ghostly#a#1")

(1) or (2) passed to querySense will return a list of possible query
strings at the next level of specificity.  (1) passed to queryWord
will do the same.  When (3) is passed to querySense, it requires a
second argument, a relation.  Possible relations are:

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

When called in this manner, querySense will return a list of related
senses.  When queryWord is called with (2), it requires a relation and
will return a list of related words (word#pos).

=head2 OTHER FUNCTIONS

"validForms" accepts a (2) query string and returns a list of all
alternate forms (alternate spellings, conjugations, plural/singular
forms, etc.) that WordNet recognizes.

"listAllWords" accepts a part of speech and returns the full list of
words in the WordNet database for that part of speech.

"level" accepts a (3) query string and returns a distance (not
necessarily the shortest or longest) to the root in the hypernym
directed acyclic graph.

"offset" accepts a (3) query string and returns the binary offset of
that sense's location in the corresponding data file.

See test.pl for additional example usage.

=head1 NOTES

Requires access to WordNet database files (data.noun/noun.dat,
index.noun/noun.idx, etc.)

=head1 COPYRIGHT

Copyright 2000, 2001, 2002 Jason Rennie <jrennie@ai.mit.edu> All
rights reserved.

This module is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 SEE ALSO

perl(1)

http://www.cogsci.princeton.edu/~wn/

http://www.ai.mit.edu/people/jrennie/WordNet/

=cut
