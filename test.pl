#!/usr/bin/perl -w
# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl test.pl'

# $Id: test.pl,v 1.15 2002/04/08 04:39:06 jrennie Exp $

my $i = 1;
BEGIN { $| = 1; print "v1.6: 1..20\nv1.7: 1..22\n"; }
END { print "not ok 1\n" unless $loaded; }
use WordNet::QueryData;
$loaded = 1;
print "ok ", $i++, "\n";

# Insert your test code below (better if it prints "ok 13"
# (correspondingly "not ok 13") depending on the success of chunk 13
# of the test code):

print "Loading index files.  This may take a while...\n";
# Uses $WNHOME environment variable
my $wn = WordNet::QueryData->new;
#my $wn = WordNet::QueryData->new("/usr/local/wordnet-1.7/dict", 1);
my $ver = $wn->version();
print "Found WordNet database version $ver\n";

scalar $wn->forms ("other sexes#1") == 3
    ? print "ok ", $i++, "\n" : print "not ok ", $i++, "\n";
scalar $wn->forms ("fussing#2") == 3
    ? print "ok ", $i++, "\n" : print "not ok ", $i++, "\n";
scalar $wn->forms ("fastest#3") == 3
    ? print "ok ", $i++, "\n" : print "not ok ", $i++, "\n";

scalar $wn->querySense ("cat") == 2
    ? print "ok ", $i++, "\n" : print "not ok ", $i++, "\n";
scalar $wn->querySense ("cat#n") == 7
    ? print "ok ", $i++, "\n" : print "not ok ", $i++, "\n";

scalar $wn->querySense ("cat#n#1", "hypo") == 2
    ? print "ok ", $i++, "\n" : print "not ok ", $i++, "\n";
($wn->queryWord("affirm#v", "ants"))[0] eq "negate#v"
    ? print "ok ", $i++, "\n" : print "not ok ", $i++, "\n";
($wn->queryWord("sure#a", "ants"))[0] eq "unsure#a"
    ? print "ok ", $i++, "\n" : print "not ok ", $i++, "\n";
scalar $wn->querySense ("cat#noun#7", "syns") == 5
    ? print "ok ", $i++, "\n" : print "not ok ", $i++, "\n";
scalar $wn->valid_forms ("lay down#v") == 2
    ? print "ok ", $i++, "\n" : print "not ok ", $i++, "\n";
scalar $wn->valid_forms ("checked#v") == 1
    ? print "ok ", $i++, "\n" : print "not ok ", $i++, "\n";

($wn->query ("cat#n#1", "glos") eq "feline mammal usually having thick soft fur and being unable to roar; domestic cats; wildcats  ") ? print
"ok ", $i++, "\n" : print "not ok ", $i++, "\n";

scalar $wn->query ("child#n#1", "syns") == 12
    ? print "ok ", $i++, "\n" : print "not ok ", $i++, "\n";

(([$wn->validForms ("lay down#2")]->[0]) eq "lay down"
    and ([$wn->validForms ("ghostliest#3")]->[0]) eq "ghostly"
    and ([$wn->validForms ("farther#4")]->[1]) eq "far")
    ? print "ok ", $i++, "\n" : print "not ok ", $i++, "\n";

($wn->querySense("authority#n#4", "attr"))[0] eq "certain#a#2"
    ? print "ok ", $i++, "\n" : print "not ok ", $i++, "\n";

if ($ver eq "1.6") {
    $wn->offset ("child#n#1") == 7153837
	? print "ok ", $i++, "\n" : print "not ok ", $i++, "\n";
    scalar $wn->querySense ("car#n#1", "mero") == 29
	? print "ok ", $i++, "\n" : print "not ok ", $i++, "\n";
    scalar $wn->listAllWords("noun") == 94474
	? print "ok ", $i++, "\n" : print "not ok ", $i++, "\n";
    scalar $wn->querySense ("run#verb") == 42
	? print "ok ", $i++, "\n" : print "not ok ", $i++, "\n";
} elsif ($ver eq "1.7") {
    scalar $wn->listAllWords("noun") == 107930
	? print "ok ", $i++, "\n" : print "not ok ", $i++, "\n";
    $wn->offset("child#n#1") == 7964378
	? print "ok ", $i++, "\n" : print "not ok ", $i++, "\n";
    scalar $wn->querySense("car#n#1", "mero") == 28
	? print "ok ", $i++, "\n" : print "not ok ", $i++, "\n";
    scalar $wn->querySense("run#verb") == 41
	? print "ok ", $i++, "\n" : print "not ok ", $i++, "\n";
    scalar $wn->offset("0#n#1") == 11356314
	? print "ok ", $i++, "\n" : print "not ok ", $i++, "\n";
    scalar $wn->forms("axes#1") == 4
	? print "ok ", $i++, "\n" : print "not ok ", $i++, "\n";
}
