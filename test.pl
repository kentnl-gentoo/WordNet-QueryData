#!/usr/bin/perl -I.. -w
# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl test.pl'

# $Id: test.pl,v 1.2 1999/09/15 13:45:59 jrennie Exp $

######################### We start with some black magic to print on failure.

# Change 1..1 below to 1..last_test_to_print .
# (It may become useful if the test is moved to ./t subdirectory.)

BEGIN { $| = 1; print "1..12\n"; }
END {print "not ok 1\n" unless $loaded;}
use WordNet::QueryData;
$loaded = 1;
print "ok 1\n";

######################### End of black magic.

# Insert your test code below (better if it prints "ok 13"
# (correspondingly "not ok 13") depending on the success of chunk 13
# of the test code):

print "Loading index files.  This may take a while...\n";
my $wn = WordNet::QueryData->new ("/usr/local.foo/dict");

$wn->forms ("blauboks", 1) eq "blaubok"
    and $wn->forms ("boogied", 2) eq "boogie"
    and $wn->forms ("ghostliest", 3) eq "ghostly"
    and $wn->forms ("farther", 4) eq "far"
    ? print "ok 2\n" : print "not ok 2\n";
scalar $wn->forms ("attorneys generals", 1) == 4
    ? print "ok 3\n" : print "not ok 3\n";
scalar $wn->forms ("other sexes", 1) == 3
    ? print "ok 4\n" : print "not ok 4\n";
scalar $wn->forms ("fussing", 2) == 3
    ? print "ok 5\n" : print "not ok 5\n";
scalar $wn->forms ("fastest", 3) == 3
    ? print "ok 6\n" : print "not ok 6\n";

scalar $wn->query ("cat") == 2
    ? print "ok 7\n" : print "not ok 7\n";

scalar $wn->query ("cat#n") == 7
    ? print "ok 8\n" : print "not ok 8\n";

scalar $wn->query ("cat#n#1", "hyponym") == 2
    ? print "ok 9\n" : print "not ok 9\n";
(!$wn->query ("cat#n#1", "ants"))
    ? print "ok 10\n" : print "not ok 10\n";
scalar $wn->query ("cat#noun#7", "syns") == 5
    ? print "ok 11\n" : print "not ok 11\n";
scalar $wn->query ("run#verb") == 42
    ? print "ok 12\n" : print "not ok 12\n";
