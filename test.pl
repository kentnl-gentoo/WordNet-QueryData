#!/usr/bin/perl -w -I/tmp
# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl test.pl'

# $Id: test.pl,v 1.9 2001/11/22 17:48:02 jrennie Exp $

######################### We start with some black magic to print on failure.

# Change 1..1 below to 1..last_test_to_print .
# (It may become useful if the test is moved to ./t subdirectory.)

BEGIN { $| = 1; print "1..20\n"; }
END {print "not ok 1\n" unless $loaded;}
use WordNet::QueryData;
$loaded = 1;
print "ok 1\n";

######################### End of black magic.

# Insert your test code below (better if it prints "ok 13"
# (correspondingly "not ok 13") depending on the success of chunk 13
# of the test code):

my $wnDir = $ENV{"WNHOME"}."/dict";

print "Loading index files.  This may take a while...\n";
my $wn = WordNet::QueryData->new ($wnDir, 0);

print "Tests 2-15 work for both WordNet 1.6 and 1.7\n";

(([$wn->forms ("blauboks#1")]->[1]) eq "blaubok"
    and ([$wn->forms ("boogied#2")]->[1]) eq "boogie"
    and ([$wn->forms ("ghostliest#3")]->[1]) eq "ghostly"
    and ([$wn->forms ("ghostliest#3")]->[0]) eq "ghostliest" # be sure we're returning the query form
    and ([$wn->forms ("farther#4")]->[1]) eq "far")
    ? print "ok 2\n" : print "not ok 2\n";

scalar $wn->forms ("attorneys generals#1") == 4
    ? print "ok 3\n" : print "not ok 3\n";
scalar $wn->forms ("other sexes#1") == 3
    ? print "ok 4\n" : print "not ok 4\n";
scalar $wn->forms ("fussing#2") == 3
    ? print "ok 5\n" : print "not ok 5\n";
scalar $wn->forms ("fastest#3") == 3
    ? print "ok 6\n" : print "not ok 6\n";

scalar $wn->query ("cat") == 2
    ? print "ok 7\n" : print "not ok 7\n";

scalar $wn->query ("cat#n") == 7
    ? print "ok 8\n" : print "not ok 8\n";

scalar $wn->query ("cat#n#1", "hypo") == 2
    ? print "ok 9\n" : print "not ok 9\n";
(!$wn->query ("cat#n#1", "ants"))
    ? print "ok 10\n" : print "not ok 10\n";
scalar $wn->query ("cat#noun#7", "syns") == 5
    ? print "ok 11\n" : print "not ok 11\n";
scalar $wn->valid_forms ("lay down#v") == 2
    ? print "ok 12\n" : print "not ok 12\n";
scalar $wn->valid_forms ("checked#v") == 1
    ? print "ok 13\n" : print "not ok 13\n";

($wn->query ("cat#n#1", "glos") eq "feline mammal usually having thick soft fur and being unable to roar; domestic cats; wildcats  ") ? print
"ok 14\n" : print "not ok 14\n";

scalar $wn->query ("child#n#1", "syns") == 12
    ? print "ok 15\n" : print "not ok 15\n";

(([$wn->valid_forms ("lay down#2")]->[0]) eq "lay down"
    and ([$wn->valid_forms ("ghostliest#3")]->[0]) eq "ghostly"
    and ([$wn->valid_forms ("farther#4")]->[1]) eq "far")
    ? print "ok 16\n" : print "not ok 16\n";

print "Tests 17-20 only work for WordNet 1.6\n";

scalar $wn->query ("run#verb") == 42
    ? print "ok 17\n" : print "not ok 17\n";

$wn->offset ("child#n#1") == 7153837
    ? print "ok 18\n" : print "not ok 18\n";

scalar $wn->query ("car#n#1", "mero") == 29
    ? print "ok 19\n" : print "not ok 19\n";

scalar $wn->list_all_words("noun") == 94474
    ? print "ok 20\n" : print "not ok 20\n";

print "Tests 21-24 only work for WordNet 1.7\n";

scalar $wn->query ("run#verb") == 41
    ? print "ok 21\n" : print "not ok 21\n";

scalar $wn->list_all_words("noun") == 107930
    ? print "ok 22\n" : print "not ok 22\n";

$wn->offset ("child#n#1") == 7964378
    ? print "ok 23\n" : print "not ok 23\n";

scalar $wn->query ("car#n#1", "mero") == 28
    ? print "ok 24\n" : print "not ok 24\n";

