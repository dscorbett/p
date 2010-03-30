#!usr/bin/perl

use strict;
use warnings;
use FileHandle;

use constant CODEPAD => 0;

$/ = "\r\n" if (CODEPAD);

############# CONSTANTS #############

use constant INVALID     => "\n";
use constant UNSPECIFIED => "";

use constant SHADE_SOLID  => substr "Û#", CODEPAD, 1;
use constant SHADE_HIGH   => substr "²*", CODEPAD, 1;
use constant SHADE_MEDIUM => substr "±.", CODEPAD, 1;
use constant SHADE_LOW    => substr "°`", CODEPAD, 1;

use constant PART_MAP      => 0;
use constant PART_ALPHABET => 1;
use constant PART_LANGUAGE => 2;
use constant PART_RELIGION => 3;
use constant PART_ETHNE    => 4;
use constant PART_STATE    => 5;
use constant PART_CITY     => 6;

use constant DEMO_ETHNE    => 0; # "demo" is short for "demographics"
use constant DEMO_RELIGION => 1;
use constant DEMO_LANGUAGE => 2;
use constant DEMO_ALPHABET => 3;

use constant ALPHABET_PARAMETERS => 0;
use constant ALPHABET_NAME       => 0;
use constant ORAL                => ("oral tradition");
use constant ORAL_SYMBOL         => "0";

use constant LANGUAGE_PARAMETERS => 1;
use constant LANGUAGE_NAME       => 0;
use constant LANGUAGE_ALPHABET   => 1;
use constant GRUNTS              => qw/grunts 0/;
use constant GRUNTS_SYMBOL       => "0";

use constant RELIGION_PARAMETERS => 3;
use constant RELIGION_NAME       => 0;
use constant RELIGION_ADJ        => 1;
use constant RELIGION_SING       => 2;
use constant RELIGION_PL         => 3;
use constant ATHEISM             => qw/atheism atheist atheist atheists/;
use constant ATHEISM_SYMBOL      => "0";

use constant ETHNE_PARAMETERS   => 3;
use constant ETHNE_SING         => 0;
use constant ETHNE_PL           => 1;
use constant ETHNE_ADJ          => 2;
use constant ETHNE_DEMOGRAPHICS => 3;
use constant HERMIT             => qw/hermit hermits eremetic 00./;
use constant HERMIT_SYMBOL      => "0";

use constant STATE_PARAMETERS => 9;
use constant STATE_INPUT      => 6;
use constant STATE_NAME       => 0;
use constant STATE_ADJ        => 1;
use constant STATE_POLITICS   => 2;
use constant STATE_LAWS       => 3;
use constant STATE_ETHNES     => 4;
use constant STATE_OFFENSE_A  => 5;
use constant STATE_DEFENSE_A  => 6;
use constant STATE_OFFENSE_N  => 7;
use constant STATE_DEFENSE_N  => 8;
use constant STATE_MONEY      => 9;
use constant STATE_DEFAULT    => ((UNSPECIFIED) x 4, (1) x 5, 0);
use constant OCEAN            => ("water", "aquatic", (UNSPECIFIED) x 2, (1) x 5, 0);
use constant OCEAN_SYMBOL     => " ";

use constant SITE_PARAMETERS => 3;
use constant SITE_INPUT      => 3;
use constant SITE_STATE      => 0;
use constant SITE_NAME       => 1;
use constant SITE_ETHNES     => 2;
use constant SITE_POPULATION => 3;
use constant SITE_DEFAULT    => ((UNSPECIFIED) x 3, 0);

use constant FOF_NEUTRAL    => 0;
use constant FOF_SMOLDERING => 1;
use constant FOF_BELLICOSE  => 2;
use constant FOF_ALLIED     => 3;

############# FORMATS #############

my ($list_state, $list_pop);
format LIST =
@<<<<<<<<<<<<<<<<<<<<<<<<<<<    @>>>>>>>>>
$list_state,                     $list_pop
.

############# SOMETHING TO LOOK AT DURING INITIALIZATION #############

#         1         2         3         4         5         6         7        
#123456789012345678901234567890123456789012345678901234567890123456789012345678
print <<INTRO;
                                                                               
                                David Corbett's                                
                                                                               
                                     WORLD                                     
                                                                               
                                   SIMULATOR                                   
                                                                               
                          (New players: type "help".)                          
                                                                               
                                                                               
This is a world simulator based somewhat on Machiavelli's "The Prince".        
It is not finished. So far, all that can be done is watch the countries of     
medieval Europe fight each other, and not too realistically either.            
                                                                               
There were originally supposed to be units moving around the world (like in    
Civilization), but they slowed the program down too much so I took them out.   
                                                                               
The game is moddable, so you can create your own map, ethnic groups, religions,
languages, alphabets, countries, and cities. For more information, see "mod" in
the help files.                                                                
                                                                               
The HELP FILES can be accessed by typing "help" followed by the topic.         
I.e. "help commands" lists available commands. "help topics" lists all topics. 
                                                                               
INTRO

############# VARIOUS VARIABLES #############

my $turn = 0;
my $passive = 0;
my $ooc = 1;
my $skip = 0;
my $repeat = "";
my $line = 0;
my $part = 0;
my @tile;
my @tileCopy;
my %ethne;
my %religion;
my %language;
my %alphabet;
my @state = [OCEAN];
my $symbols = OCEAN_SYMBOL;
my %area;
my %areaCopy;
my @city;
my @fof;     # outward diplomatic relations (i.e. "allied", "at war")
my @opinion; # internal opinions as scalars (>0 = like; <0 = dislike)

############# INITIALIZATION #############

while (<DATA>) {
  $line++;
  chomp;
  next if ($_ =~ /^#/);
  if ($_ eq "") {
    $part++;
    
  ############# DEFAULT SITE INFORMATION #############
    
    if ($part == PART_CITY) {
      foreach my $y (0 .. $#tile) {
        foreach my $x (0 .. $#{$tile[$y]}) {
          $tile[$y][$x] = [index ($symbols, $tile[$y][$x]), (INVALID) x (SITE_PARAMETERS - 1)];
          $tile[$y][$x][SITE_STATE]      = 0 if ($tile[$y][$x][SITE_STATE] == -1);
          $tile[$y][$x][SITE_POPULATION] = $tile[$y][$x][SITE_STATE] ? 5000 : 0;
          $tile[$y][$x][SITE_ETHNES]     = state_code ($tile[$y][$x][SITE_STATE], STATE_ETHNES);
#          $tileCopy[$y][x] = $tile[$y][$x];
        }
      }
    }
    next;
  }
  
  ############# PARTS #############
  
  if ($part == PART_MAP) {
    push @tile, [split //, $_];
  } elsif ($part == PART_ETHNE) {
    my @ethne = split /\s*:\s*/, $_;
    my $ethne = shift @ethne;
    die "Ethne \"$ethne\" must have the format \"symbol:singular:plural:adjective:demographics\" on line $line\n" if ($#ethne != ETHNE_PARAMETERS);
    die "Demographics in ethne \"$ethne\" must have the format \"RLA\" on line $line\n" if ($ethne[ETHNE_DEMOGRAPHICS] !~ /(.)(.)(.)/);
    my $religion = $1;
    my $language = $2;
    my $alphabet = $3;
    die "Religion $religion does not exist for the $ethne[ETHNE_PL] on line $line\n" unless (exists $religion{$religion});
    die "Language $language does not exist for the $ethne[ETHNE_PL] on line $line\n" unless (exists $language{$language});
    $alphabet = alphabet_language ($language) if ($alphabet eq ".");
    die "Alphabet $alphabet does not exist for the $ethne[ETHNE_PL] on line $line\n" unless (exists $alphabet{$alphabet});
    $ethne[ETHNE_DEMOGRAPHICS] = "$religion$language$alphabet";
    $ethne{$ethne} = [@ethne];
  } elsif ($part == PART_RELIGION) {
    my @religion = split /\s*:\s*/, $_;
    my $religion = shift @religion;
    die "Religion \"$religion\" must have the format \"symbol:name:adjective:singular:plural\" on line $line\n" if ($#religion != RELIGION_PARAMETERS);
    $religion{$religion} = [@religion];
  } elsif ($part == PART_LANGUAGE) {
    my @language = split /\s*:\s*/, $_;
    my $language = shift @language;
    die "Language \"$language\" must have the format \"symbol:name:alphabet\" on line $line\n" if ($#language != LANGUAGE_PARAMETERS);
    die "Alphabet $language[LANGUAGE_ALPHABET] does not exist for the language $language[LANGUAGE_NAME] on line $line\n" unless (exists $alphabet{$language[LANGUAGE_ALPHABET]});
    $language{$language} = [@language];
  } elsif ($part == PART_ALPHABET) {
    my @alphabet = split /\s*:\s*/, $_;
    my $alphabet = shift @alphabet;
    die "Alphabet \"$alphabet\" must have the format \"symbol:name\" on line $line\n" if ($#alphabet != ALPHABET_PARAMETERS);
    $alphabet{$alphabet} = [@alphabet];
  } elsif ($part == PART_STATE) {
    my @tmp = split /\s*:\s*/, $_, STATE_INPUT;
    my $symbol = shift @tmp;
    while ($#tmp <= STATE_INPUT) {
      push @tmp, (STATE_DEFAULT)[$#tmp];
    }
    
    my @ethnes = split /\s+/, $tmp[STATE_ETHNES];
    @ethnes = split //, $tmp[STATE_ETHNES] unless ($#ethnes);
    foreach (@ethnes) {
      die "Ethne $_ cannot exist in $tmp[STATE_NAME] on line $line\n" unless (exists $ethne{substr $_, 0, 1});
      $_ .= "1" if (1 == length $_);
      die "Ethne proportion " . substr ($_, 1) . " is not numeric but should be, on line $line\n" if (substr ($_, 1) == 0);
    }
    $tmp[STATE_ETHNES] = join " ", @ethnes;
    
    push @state, [@tmp[0 .. $#tmp]];
    $symbols .= $symbol;
  } elsif ($part == PART_CITY) {
    my @tmp = split /\s*:\s*/, $_, SITE_PARAMETERS + 1;
    my ($y, $x) = (shift @tmp, shift @tmp);
    die "A city can't be in the water at ($y,$x) on line $line\n" if ($tile[$y][$x][SITE_STATE] == 0);
    while ($#tmp < SITE_INPUT) {
      push @tmp, (SITE_DEFAULT)[$#tmp];
    }
    $tmp[SITE_POPULATION - 1] = 100_000;
    
    my @ethnes = split /\s+/, $tmp[SITE_ETHNES - 1];
    @ethnes = split //, $tmp[SITE_ETHNES - 1] unless ($#ethnes);
    foreach (@ethnes) {
      die "Ethne $_ cannot live in $tmp[SITE_NAME - 1] on line $line\n" unless (exists $ethne{substr $_, 0, 1});
      $_ .= "1" if (1 == length $_);
      die "Ethne proportion " . substr ($_, 1) . " is not numeric but should be, on line $line\n" if (substr ($_, 1) == 0);
    }
    $tmp[SITE_ETHNES - 1] = join " ", @ethnes;
    if ($tmp[SITE_ETHNES - 1] eq UNSPECIFIED) {
      $tmp[SITE_ETHNES - 1] = $state[$tile[$y][$x][SITE_STATE]][STATE_ETHNES];
    }
      
    foreach (0 .. $#tmp) {
      $tile[$y][$x][$_ + 1] = $tmp[$_] unless ($tmp[$_] eq UNSPECIFIED);
    }
  }
}

############# INITIAL DIPLOMATIC RELATIONS #############

foreach my $s1 (0 .. $#state) {
  my @o;
  foreach (0 .. $#state) {
    push @o, {};
  }
  push @opinion, [@o];
  
  next unless ($s1);
  my $l1 = $state[$s1][STATE_LAWS];
  foreach my $s2 (1 .. $#state) {
    update ($s1, $s2);
  }
}

my $toUpdate = "";

sub update {
  my ($s1, $s2) = (shift, shift);
#print "Updating $s1 ($s2)... ";
  return if ($s1 == $s2);
  my ($l1, $l2) = (state_code ($s1, STATE_LAWS), state_code ($s2, STATE_LAWS));
  $opinion[$s1][$s2]{"+l-"} = 0;
  $opinion[$s1][$s2]{"+l-"} += isLaw ($s1, "+") && isLaw ($s2, "+") ?  5 : 0;
  $opinion[$s1][$s2]{"+l-"} += isLaw ($s1, "+") && isLaw ($s2, "l") ?  0 : 0;
  $opinion[$s1][$s2]{"+l-"} += isLaw ($s1, "+") && isLaw ($s2, "-") ? -3 : 0;
  $opinion[$s1][$s2]{"+l-"} += isLaw ($s1, "l") && isLaw ($s2, "+") ?  2 : 0;
# $opinion[$s1][$s2]{"+l-"} += isLaw ($s1, "l") && isLaw ($s2, "l") ?  0 : 0;
# $opinion[$s1][$s2]{"+l-"} += isLaw ($s1, "l") && isLaw ($s2, "-") ?  0 : 0;
  $opinion[$s1][$s2]{"+l-"} += isLaw ($s1, "-") && isLaw ($s2, "+") ? -5 : 0;
  $opinion[$s1][$s2]{"+l-"} += isLaw ($s1, "-") && isLaw ($s2, "l") ?  3 : 0;
  $opinion[$s1][$s2]{"+l-"} += isLaw ($s1, "-") && isLaw ($s2, "-") ?  2 : 0;
#print "$opinion[$s1][$s2]{\"+l-\"}\n";
}

############# TESTING #############

#foreach my $r (0 .. $#tile) {
#  print "row $r:\n";
#  foreach my $c (0 .. $#{$tile[$r]}) {
#    print "col $c: ";
#    foreach my $i (@{$tile[$r][$c]}) {
#      print "$i ";
#    }
#    print "\n";
#  }
#  print "\n";
#}
#
=pod
foreach my $s (@state) {
  print "$$s[STATE_NAME] ($$s[STATE_DETAILS])\n";
}
print "\n";
=cut
#
#no warnings;
#foreach my $r (0 .. $#tile) {
#  foreach my $c (0 .. $#{$tile[$r]}) {
#    print "($r,$c) $tile[$r][$c][SITE_NAME]: " . state_loc ($r, $c, STATE_ADJ) . " site in " . state_loc ($r, $c, STATE_NAME);
#    print "\n";
#  }
#}
#use warnings;
#eval "while ((my \$key, my \$value) = each (\%$_)) { print \$key . \"=>\" . join (\",\", \@{\$value}) . \"\\n\"; }" foreach (qw/ethne religion language alphabet/);

############# RUNNING #############

#         1         2         3         4         5         6         7        
#123456789012345678901234567890123456789012345678901234567890123456789012345678
my %help =
("" => <<_,
To do anything in this game you have to type a command (q.v.) at the prompt.
_

"about" => <<ABOUT,
This world simulator was created by David Corbett.
ABOUT

"command" => <<COMMAND,
quit          Quit.
help [foo]   *Help (about "foo").
map           The map.
map ABC       Highlight the countries with the symbols A, B, and C.
city X        List the cities of a country.
cities        The map, only showing cities.
info X        Information about a country.
census        Ordered list of states by population.
size          Ordered list of states by area.
at y x        What is at and around (y,x)?
near X        The neighbors of a country.
threat A B    A's threat analysis of B.
fof           The diplomatic relations of all countries.
date          The date in ISO 8601 format.
o A B         The diplomatic relations of two countries.
skip n        Skip n turns (equivalent to "repeat <zzz> n").
repeat n foo  Input "foo" for the next n turns.
[ENTER]       Does nothing.
[AUGHT ELSE] *Does nothing.

* Pauses the passage of time for that turn.
COMMAND

"date" => <<DATE,
Each turn corresponds to a week. The game starts on 980-W01.
DATE

"fof" => <<FOF,
Friend Or Foe.
FOF

"generic" => <<GENERIC,
Ethnic groups are not finished yet, so most countries have a placeholder.
Generic humans are Protestants, speak Galician, and use the Elder Futhark.

... Why not?
GENERIC

"help" => <<HELP,
Okay, okay; calm down. Just type "help" followed by your topic.
HELP

"info" => <<INFO,
All you could ever want to know about a state.
INFO

"law" => <<LAW,
Laws represent the laws, customs, practices and general zeitgeist of a state.
At least, that's the plan; for now, there are only three laws: +, l, and -.
+ means it's good, l neutral, and - evil. They are arbitrarily assigned.
LAW

"map" => <<MAP,
The map is represented by text, where spaces are the oceans and every other
character represents a different country.

The game world is a genericized version of Europe in c. AD 1000, but it's not
meant to be accurate.
MAP

"mod" => <<MOD,
You can mod a lot in this game. Just open the file p.pl that you ran to play
this and go to the line that says __DATA__. Everything below that is moddable.

Lines beginning with # are ignored. The seven sections are separated by single
blank lines.

The map is pretty self-explanatory. The numbers on the sides are to make
coordinates easier, but they are converted into oceans before play begins.

Writing systems are symbol:name
Languages           symbol:name:alphabet
Religions           symbol:name:person:people:adjective
Ethnic groups       symbol:person:people:adjective:ReligionLanguageAlphabet
                    If "Alphabet" is "." it uses the default from Language.
States              symbol:name:adjective:?:laws:predominant ethnic group
Cities              y-coordinate:x-coordinate:name[:local ethnic group(s)]
MOD

"nothing" => <<NOTHING,
Cities, ethnicities, languages, religions, and alphabets do nothing... for now.
NOTHING

"quit" => <<QUIT,
Self-explanatory: it quits the program. But why would you want to?
QUIT

"topic" => <<TOPIC,
about
command
fof
generic
help
info
law
map
mod
nothing
quit
topic
war
TOPIC

"war" => <<WAR,
Wars start when one country hates another and is confident that it can win.
A state attacks neighboring states only. Wars never end. Little states
currently have the advantage, so in the long run, all states will tend to have
the same area.
WAR
);
my %synonym = ("cmd"               => "command",
               "commands"          => "command",
               "generic human"     => "generic",
               "generic humans"    => "generic",
               "generically human" => "generic",
               "me"                => "help",
               "laws"              => "law",
               "alphabet"          => "nothing",
               "alphabets"         => "nothing",
               "city"              => "nothing",
               "cities"            => "nothing",
               "ethne"             => "nothing",
               "ethnes"            => "nothing",
               "ethnic group"      => "nothing",
               "ethnic groups"     => "nothing",
               "language"          => "nothing",
               "languages"         => "nothing",
               "religion"          => "nothing",
               "religions"         => "nothing",
               "topics"            => "topic",
               "wars"              => "war",
               );

#&map ();
my @inputs = ("map", "skip 50", "map");
while (1) {
  unless ($ooc) {
    
  ############# STATES #############
    
    foreach my $s1 (1 .. $#state) {
      update ($s1) if ($toUpdate =~ /,$s1,/);
      $toUpdate =~ s/,$s1,/,/;
      
#     my $l1 = $state[$s1][STATE_LAWS];
      foreach my $s2 (1 .. $#state) {
        
    ############# TAKING ACTION #############
  
        if (ambassador ($s2, $s1) == FOF_BELLICOSE || (relations ($s1, $s2) < 0 && threat ($s1, $s2) < 1)) {
          print &state_symbol (substr ($symbols, $s1, 1), STATE_NAME) . " has declared war on " . state_symbol (substr ($symbols, $s2, 1), STATE_NAME) . "!\n" if (ambassador ($s1, $s2, FOF_BELLICOSE) && $passive);
        }
        if (relations ($s1, $s2) > 3 && relations ($s2, $s1) > 3) {
          print &state_symbol (substr ($symbols, $s1, 1), STATE_NAME) . " and " . state_symbol (substr ($symbols, $s2, 1), STATE_NAME) . " have become allies.\n" if (ambassador ($s1, $s2, FOF_ALLIED) && $passive);
        }
        my $choice = int rand 3;
        if ($choice == 0) {
          
        } elsif ($choice == 1) {
          
        } elsif ($choice == 2) {
          
        }
      }
      
      ############# LEGISLATION #############
      
      if (scalar foes ($s1, 0) > 3) {
#        legislate ($s1, "D");
      }
    }
    
      ############# WAR #############
    
    @tileCopy = @tile;
    %areaCopy = %area;
    foreach my $y (0 .. int ($#tile)) {
      foreach my $x (0 .. int ($#{$tile[$y]})) {
        my @environs;
        foreach my $dy (-1 .. 1) {
          foreach my $dx (-1 .. 1) {
            next unless ($dy || $dx);
            next unless (valid_loc ($y + $dy, $x + $dx));
            push @environs, [$y + $dy, $x + $dx];
          }
        }
        foreach (@environs) {
          my ($ey, $ex, $us) = ($$_[0], $$_[1], $tile[$y][$x][SITE_STATE]);
          my $them = site_loc ($ey, $ex, SITE_STATE);
          if (ambassador ($us, $them) == FOF_BELLICOSE) {
            my $chance = (state_code ($us, STATE_OFFENSE_A) / area ($us)) / (state_code ($us, STATE_OFFENSE_A) / area ($us) + state_code ($them, STATE_DEFENSE_A) / area ($them));
            transfer ($ey, $ex, $us) if (chance ($chance));
          }
        }
      }
    }
    @tile = @tileCopy;
    %area = %areaCopy;
    
    $turn++;
  }
  
  ############# INPUT #############
  
  if (CODEPAD) {
    die unless (@inputs || $skip > 0);
  }
  print "$skip" if ($skip > 0);
  print ">";
  my $input;
  unless (CODEPAD) {
    $input = ($skip > 0) ? $repeat : <>;
  } else {
    $input = ($skip > 0) ? $repeat : shift @inputs;
  }
  $input = INVALID unless (defined $input);
  print "$input\n" if ($skip > 0 || CODEPAD);
  
  $skip--;
  chomp $input;
  $input =~ s/\s+/ /g;
  $input =~ s/^ //g;
  $input =~ s/ $//g;
  $passive = 0;
  $ooc = 0;
  if ($input =~ /^((qq?(uit)?)|cls|exit)$/i) {
    last;
  } elsif ($input =~ /^h(elp)?( (.+))?$/i) {
    $ooc = 1;
    help ($3);
  } elsif ($input =~ /^map( (.+))?$/i) {
    &map ($2);
  } elsif ($input =~ /^cities$/i) {
    cities ();
  } elsif ($input =~ /^city (.*)$/i) {
    $ooc = 1;
    city ($1);
  } elsif ($input =~ /^info (.*)$/i) {
    info ($1);
  } elsif ($input =~ /^census$/i) {
    census ();
  } elsif ($input =~ /^size$/i) {
    size ();
  } elsif ($input =~ /^at (\d+) (\d+)$/i) {
    at ($1, $2);
  } elsif ($input =~ /^near (.*)$/i) {
    near ($1);
  } elsif ($input =~ /^threat (.*) (.*)$/i) {
    threatDoc ($1, $2);
  } elsif ($input =~ /^fof$/i) {
    fof ();
  } elsif ($input =~ /^date$/i) {
    $ooc = 1;
    date ();
  } elsif ($input =~ /^p (.)$/i) {
    power ($1);
  } elsif ($input =~ /^o (.+) (.+)$/i) {
    o ($1, $2);
  } elsif ($input =~ /^skip (\d+)$/i) {
    $skip = $1;
    $repeat = "";
  } elsif ($input =~ /^repeat (\d+) (.+)$/i) {
    $skip = $1;
    $repeat = $2;
  } elsif ($input =~ /^$/) {
    $passive = 1;
  } else {
    $ooc = 1;
  }
}

############# GENERAL-PURPOSE SUBROUTINES #############

sub valid_loc {
  my ($y, $x) = (shift, shift);
  $y < 0 || $y > $#tile || $x < 0 || $x > $#{$tile[$y]} ? return 0 : return 1;
}

sub chance {
  my $percentage = shift;
  return $percentage > rand 100;
}

sub escape {
  my $str = shift;
  return undef unless (defined $str);
  $str =~ s/(\{|\}|\*|\+|\\|\?|\(|\)|\\|\$|\[|\])/\\$1/;
  return $str;
}

############# DIPLOMATIC SUBROUTINES #############

sub relations {
  my ($s1, $s2, $print) = (shift, shift, shift);
  print &state_symbol (substr ($symbols, $s1, 1), STATE_NAME) . " - " . state_symbol (substr ($symbols, $s2, 1), STATE_NAME) . ":\n" if (defined $print);
  my $sum;
#  map $sum += $_, values %{$opinion[$s1][$s2]};
  while (my ($key, $value) = each (%{$opinion[$s1][$s2]})) {
    print "$key => $value\n" if (defined $print);
    $sum += $value;
  }
  $sum = 0 unless (defined $sum);
  print "-----------\nTotal: $sum\n" if (defined $print);
  return 0 unless ($sum);
  return $sum;
}

sub friends {
  my ($state, $threshold) = (shift, shift);
  my @out;
  foreach (1 .. $#state) {
    next if ($state == $_);
    push @out, $_ if (relations ($state, $_) >= $threshold);
  }
  return @out;
}

sub neutral {
  my ($state, $min, $max) = (shift, shift, shift);
  my @out;
  foreach (1 .. $#state) {
    next if ($state == $_);
    push @out, $_ if (relations ($state, $_) >= $min && relations ($state, $_) <= $max);
  }
  return @out;
}

sub foes {
  my ($state, $threshold) = (shift, shift);
  my @out;
  foreach (1 .. $#state) {
    next if ($state == $_);
    push @out, $_ if (relations ($state, $_) <= $threshold);
  }
  return @out;
}

sub ambassador {
  my ($s1, $s2) = (shift, shift);
  my $old = defined $fof[$s1][$s2] ? $fof[$s1][$s2] : FOF_NEUTRAL;
  defined $_[0] ? my $f = shift : return $old;
  $fof[$s1][$s2] = $f;
  $fof[$s2][$s1] = $f;
  return ($old != $fof[$s1][$s2]);
}

sub transfer {
  my ($y, $x, $conq) = (shift, shift, shift);
  if ($passive) {
    print &state_code ($conq, STATE_NAME) . " has taken ";
    site_loc ($y, $x, SITE_NAME) ne INVALID ? print &site_loc ($y, $x, SITE_NAME) : print "some land";
    print " from " . state_loc ($y, $x, STATE_NAME) . ".\n";
  }
  $areaCopy{$tile[$y][$x][SITE_STATE]}--;
  $tileCopy[$y][$x][SITE_STATE] = $conq;
  $areaCopy{$conq}++;
}

############# THREAT ANALYSIS SUBROUTINES #############

sub threatDoc {
  my ($us, $them) = (shift, shift);
  my ($usI, $themI) = (index ($symbols, $us), index $symbols, $them);
  if (-1 == $usI) {
    print "Invalid state: $us\n";
    return;
  }
  if (-1 == $themI) {
    print "Invalid state: $them\n";
    return;
  }
  print "*** TOP SECRET ***\n" . uc state_code ($usI, STATE_ADJ) . " THREAT ANALYSIS OF " . uc state_code ($themI, STATE_NAME) . "\n";
  print "Amity/enmity:    " . relations ($usI, $themI) . "\n";
  print "Border length:   " . internationalBorder ($usI, $themI) . "\n";
  print "Total perimeter: " . perimeter ($themI) . "\n";
  print "Area:            " . area ($themI) . "\n";
  print "Population:      " . population ($themI) . "\n";
  print "THREAT:          " . threat ($usI, $themI) . "\n";
}

sub threat {
  my ($us, $them) = (shift, shift);
  return internationalBorder ($us, $them) / (area ($us) + 1) * population ($them) / (population ($us) + 1);
}

sub internationalBorder {
  my ($s1, $s2, $border) = (shift, shift, 0);
  foreach my $y (0 .. $#tile) {
    foreach my $x (0 .. $#{$tile[$y]}) {
      next unless (code_loc ($y, $x) == $s1);
      my @environs = near_loc ($y, $x);
      foreach (0 .. $#environs) {
        next if ($environs[$_] eq INVALID);
        next unless ($environs[$_] == $s2);
        if ("1346" =~ $_) { # if $_ is 1, 3, 4, or 6 (N, W, E, or S)
          $border++;
        } else {
          $border++ unless ($environs[counterclockwise ($_)] == $s2 && $environs[clockwise ($_)] == $s1 || $environs[counterclockwise ($_)] == $s1 && $environs[clockwise ($_)] == $s2);
        }
      }
    }
  }
  return $border;
}

sub perimeter {
  my ($s1, $border) = (shift, 0);
  foreach my $y (0 .. $#tile) {
    foreach my $x (0 .. $#{$tile[$y]}) {
      next unless (code_loc ($y, $x) == $s1);
      my @environs = near_loc ($y, $x);
      foreach (0 .. $#environs) {
        next if ($environs[$_] eq INVALID);
        next if ($environs[$_] == $s1);
        if ("1346" =~ $_) { # if $_ is 1, 3, 4, or 6 (N, W, E, or S)
          $border++;
        } else {
          $border++ unless ($environs[counterclockwise ($_)] != $s1 && $environs[clockwise ($_)] == $s1 || $environs[counterclockwise ($_)] == $s1 && $environs[clockwise ($_)] != $s1);
        }
      }
    }
  }
  return $border;
}

sub clockwise {
  my ($dir, $dirs) = (shift, "012476530");
  return substr $dirs, index ($dirs, $dir) + 1, 1;
}

sub counterclockwise {
  my ($dir, $dirs) = (shift, "012476530");
  return substr $dirs, rindex ($dirs, $dir) - 1, 1;
}

sub area {
  my $state = shift;
  return $area{$state} if (defined $area{$state});
  if ($state > length $symbols) {
    print "Invalid state: $state\n";
    return;
  }
  my $area = 0;
  foreach my $y (0 .. $#tile) {
    foreach my $x (0 .. $#{$tile[$y]}) {
      $area++ if (code_loc ($y, $x) == $state);
    }
  }
  $area{$state} = $area;
  $areaCopy{$state} = $area;
  return $area;
}

############# OBSOLETE DIPLOMATIC SUBROUTINES #############

=pod
sub list_fof {
  my ($state, $relationship) = (shift, shift);
  my @out;
  foreach (0 .. $#state) {
    push @out, $_ if ($fof[$state][$_] == $relationship);
  }
  return @out;
}
=cut

############# LEGISLATIVE SUBROUTINES #############

sub isLaw {
  my ($state, $law) = (shift, shift);
  my $reLaw = escape ($law);
  return (state_code ($state, STATE_LAWS) =~ /$reLaw/);
}

sub legislate {
  my ($state, $law) = (shift, shift);
  unless (isLaw ($state, $law)) {
    $state[$state][STATE_LAWS] .= $law;
    print &state_symbol (substr $symbols, $state, 1) . " passes a new law.\n";
    $toUpdate .= ",$state,";
  }
}

############# SUBROUTINES GIVEN A STATE SYMBOL #############

sub state_symbol {
  my ($symbol, $i) = (shift, shift);
  $i = 0 unless (defined $i);
  -1 == index ($symbols, $symbol) ? return INVALID : return $state[index ($symbols, $symbol)][$i];
}

sub state_code {
  my ($code, $i) = (shift, shift);
  $i = 0 unless (defined $i);
  die "Invalid code: $code\n" if ($code > length ($symbols));
  my $symbol = substr $symbols, $code, 1;
  -1 == index ($symbols, $symbol) ? return INVALID : defined $state[index ($symbols, $symbol)][$i] ? return $state[index ($symbols, $symbol)][$i] : return UNSPECIFIED;
}

sub code_symbol { # Is this subroutine downright useless?
  my $symbol = shift;
  -1 == index ($symbols, $symbol) ? return -1 : return index ($symbols, $symbol);
}

############# SUBROUTINES GIVEN A LOCATION OR STATE #############

sub state_loc {
  my ($y, $x) = (shift, shift);
  return INVALID unless (valid_loc ($y, $x));
  my $i = shift;
  $i = 0 unless (defined $i);
  return $state[$tile[$y][$x][SITE_STATE]][$i];
}

sub code_loc {
  my ($y, $x) = (shift, shift);
  return INVALID unless (valid_loc ($y, $x));
  return $tile[$y][$x][SITE_STATE];
}

sub near_loc {
  my @environs;
  my ($y, $x) = (shift, shift);
  foreach my $dy (-1 .. 1) {
    foreach my $dx (-1 .. 1) {
      next unless ($dy || $dx);
      push @environs, code_loc ($y + $dy, $x + $dx);
    }
  }
  return @environs;
}

sub near_state {
  my $state = shift;
  my @neighbors;
  foreach my $y (0 .. $#tile) {
    foreach my $x (0 .. $#{$tile[$y]}) {
      push @neighbors, near_loc ($y, $x) if (code_symbol ($state) == $tile[$y][$x][SITE_STATE]);
    }
  }
  my %seen = ();
  @neighbors = grep {!$seen{$_}++ && $_ ne INVALID} @neighbors;
  return @neighbors;
}

sub sites_state {
  my $state = shift;
  my @sites;
  foreach my $y (0 .. $#tile) {
    foreach my $x (0 .. $#{$tile[$y]}) {
      push @sites, [$y, $x] if (code_symbol ($state) == $tile[$y][$x][SITE_STATE]);
    }
  }
  return @sites;
}

sub site_loc {
  my ($y, $x) = (shift, shift);
  return INVALID if ($y < 0 || $x < 0 || $y > $#tile || $x > $#{$tile[$y]});
  my $i = shift;
  $i = 0 unless (defined $i);
  defined $tile[$y][$x][$i] ? return $tile[$y][$x][$i] : return $tile[$y][$x][$i];
}

sub city_loc {
  my ($y, $x) = (shift, shift);
  return INVALID if ($y < 0 || $x < 0 || $y > $#tile || $x > $#{$tile[$y]});
  defined $tile[$y][$x][SITE_NAME] ? return 1 : return 0;
}

############# DEMOGRAPHICS SUBROUTINES #############

sub ethne_loc {
  my ($y, $x) = (shift, shift);
  return INVALID if ($y < 0 || $x < 0 || $y > $#tile || $x > $#{$tile[$y]});
  return $tile[$y][$x][SITE_ETHNES];
}

sub religion_loc {
  my ($y, $x) = (shift, shift);
  return INVALID if ($y < 0 || $x < 0 || $y > $#tile || $x > $#{$tile[$y]});
  my @ethnes = split / /, $tile[$y][$x][SITE_ETHNES];
  my %here;
  foreach (@ethnes) {
    $here{religion_ethne (substr $_, 0, 1)} += substr $_, 1;
  }
  my @religion;
  while (my ($key, $value) = each (%here)) {
    push @religion, "$key$value";
  }
  return join " ", @religion;
}

sub language_loc {
  my ($y, $x) = (shift, shift);
  return INVALID if ($y < 0 || $x < 0 || $y > $#tile || $x > $#{$tile[$y]});
  my @ethnes = split / /, $tile[$y][$x][SITE_ETHNES];
  my %here;
  foreach (@ethnes) {
    $here{language_ethne (substr $_, 0, 1)} += substr $_, 1;
  }
  my @language;
  while (my ($key, $value) = each (%here)) {
    push @language, "$key$value";
  }
  return join " ", @language;
}

sub alphabet_loc {
  my ($y, $x) = (shift, shift);
  return INVALID if ($y < 0 || $x < 0 || $y > $#tile || $x > $#{$tile[$y]});
  my @ethnes = split / /, $tile[$y][$x][SITE_ETHNES];
  my %here;
  foreach (@ethnes) {
    $here{alphabet_ethne (substr $_, 0, 1)} += substr $_, 1;
  }
  my @alphabet;
  while (my ($key, $value) = each (%here)) {
    push @alphabet, "$key$value";
  }
  return join " ", @alphabet;
}

############# DEMOGRAPHIC INFERENCE SUBROUTINES #############

sub religion_ethne {
  if (exists $ethne{$_[0]}) {
    return substr $ethne{$_[0]}[ETHNE_DEMOGRAPHICS], 0, 1;
  } else {
    die "$_[0] is not a valid ethne symbol on line $line.\n";
  }
}

sub language_ethne {
  if (exists $ethne{$_[0]}) {
    return substr $ethne{$_[0]}[ETHNE_DEMOGRAPHICS], 1, 1;
  } else {
    die "$_[0] is not a valid ethne symbol on line $line.\n";
  }
}

sub alphabet_ethne {
  if (exists $ethne{$_[0]}) {
    return substr $ethne{$_[0]}[ETHNE_DEMOGRAPHICS], 2, 1;
  } else {
    die "$_[0] is not a valid ethne symbol on line $line.\n";
  }
}

sub alphabet_language {
  if (exists $language{$_[0]}[LANGUAGE_ALPHABET]) {
    return $language{$_[0]}[LANGUAGE_ALPHABET];
  } else {
    die "$_[0] is not a valid language symbol on line $line.\n";
  }
}

############# GENERAL DEMOGRAPHICS SUBROUTINES #############

sub pop_loc {
  my ($y, $x, $total) = (shift, shift, 0);
  my @ethnes = split / /, $tile[$y][$x][SITE_ETHNES];
  return 0 unless (@ethnes);
  foreach (@ethnes) {
    $total += substr $_, 1;
  }
  return $total;
}

sub ethne_state {
  return ethne_code (index $symbols, $_[0]);
}

sub religion_state {
  return religion_code (index $symbols, $_[0]);
}

sub language_state {
  return language_code (index $symbols, $_[0]);
}

sub alphabet_state {
  return alphabet_code (index $symbols, $_[0]);
}

sub ethne_code {
  my $code = shift;
  my %ethnes;
  foreach my $y (0 .. $#tile) {
    foreach my $x (0 .. $#{$tile[$y]}) {
      next unless (site_loc ($y, $x, SITE_STATE) == $code);
      my %eth = ethnePop_loc ($y, $x);
      while (my ($key, $value) = each (%eth)) {
        $ethnes{$key} += $value;
      }
    }
  }
  while (my ($key, $value) = each (%ethnes)) {
    print "$ethne{$key}[ETHNE_PL]: $value\n";
  }
  return %ethnes;
}

sub religion_code {
  my $code = shift;
  my %religions;
  foreach my $y (0 .. $#tile) {
    foreach my $x (0 .. $#{$tile[$y]}) {
      next unless (site_loc ($y, $x, SITE_STATE) == $code);
      my %rel = religionPop_loc ($y, $x);
      while (my ($key, $value) = each (%rel)) {
        $religions{$key} += $value;
      }
    }
  }
  return %religions;
}

sub language_code {
  my $code = shift;
  my %languages;
  foreach my $y (0 .. $#tile) {
    foreach my $x (0 .. $#{$tile[$y]}) {
      next unless (site_loc ($y, $x, SITE_STATE) == $code);
      my %lan = languagePop_loc ($y, $x);
      while (my ($key, $value) = each (%lan)) {
        $languages{$key} += $value;
      }
    }
  }
  return %languages;
}

sub alphabet_code {
  my $code = shift;
  my %alphabets;
  foreach my $y (0 .. $#tile) {
    foreach my $x (0 .. $#{$tile[$y]}) {
      next unless (site_loc ($y, $x, SITE_STATE) == $code);
      my %alp = alphabetPop_loc ($y, $x);
      while (my ($key, $value) = each (%alp)) {
        $alphabets{$key} += $value;
      }
    }
  }
  return %alphabets;
}

sub ethnePop_loc {
  my ($y, $x) = (shift, shift);
  return INVALID unless (valid_loc ($y, $x));
  my @ethnes = split / /, $tile[$y][$x][SITE_ETHNES];
  return INVALID unless (@ethnes);
  my %eth;
  foreach (@ethnes) {
    my $eth = substr $_, 0, 1;
    $eth{$eth} += site_loc ($y, $x, SITE_POPULATION) / pop_loc ($y, $x) * substr $_, 1;
#    print "$ethne{$eth}[ETHNE_PL]: $eth{$eth} of " . site_loc ($y, $x, SITE_POPULATION) . "\n";
  }
  return %eth;
}

sub religionPop_loc {
  my ($y, $x) = (shift, shift);
  return INVALID unless (valid_loc ($y, $x));
  my @ethnes = split / /, $tile[$y][$x][SITE_ETHNES];
  return INVALID unless (@ethnes);
  my %rel;
  foreach (@ethnes) {
    my $rel = religion_ethne (substr $_, 0, 1);
    $rel{$rel} += site_loc ($y, $x, SITE_POPULATION) / pop_loc ($y, $x) * substr $_, 1;
#    print "$religion{$rel}[RELIGION_NAME]: $rel{$rel} of " . site_loc ($y, $x, SITE_POPULATION) . "\n";
  }
  return %rel;
}

sub languagePop_loc {
  my ($y, $x) = (shift, shift);
  return INVALID unless (valid_loc ($y, $x));
  my @ethnes = split / /, $tile[$y][$x][SITE_ETHNES];
  return INVALID unless (@ethnes);
  my %lan;
  foreach (@ethnes) {
    my $lan = language_ethne (substr $_, 0, 1);
    $lan{$lan} += site_loc ($y, $x, SITE_POPULATION) / pop_loc ($y, $x) * substr $_, 1;
#    print "$language{$lan}[LANGUAGE_NAME]: $lan{$lan} of " . site_loc ($y, $x, SITE_POPULATION) . "\n";
  }
  return %lan;
}

sub alphabetPop_loc {
  my ($y, $x) = (shift, shift);
  return INVALID unless (valid_loc ($y, $x));
  my @ethnes = split / /, $tile[$y][$x][SITE_ETHNES];
  return INVALID unless (@ethnes);
  my %alp;
  foreach (@ethnes) {
    my $alp = alphabet_ethne (substr $_, 0, 1);
    $alp{$alp} += site_loc ($y, $x, SITE_POPULATION) / pop_loc ($y, $x) * substr $_, 1;
#    print "$alphabet{$alp}[ALPHABET_NAME]: $alp{$alp} of " . site_loc ($y, $x, SITE_POPULATION) . "\n";
  }
  return %alp;
}

############# DEMOGRAPHICS PRINTING SUBROUTINES #############

sub print_ethnes {
  my @ethnes = split / /, shift;
  my @out;
  foreach (@ethnes) {
    push @out, $ethne{substr $_, 0, 1}[ETHNE_PL];
  }
  return join ", ", @out;
}

sub print_religions {
  my @religions = split / /, shift;
  my @out;
  foreach (@religions) {
    push @out, $religion{substr $_, 0, 1}[RELIGION_NAME];
  }
  return join ", ", @out;
}

sub print_languages {
  my @languages = split / /, shift;
  my @out;
  foreach (@languages) {
    push @out, $language{substr $_, 0, 1}[LANGUAGE_NAME];
  }
  return join ", ", @out;
}

sub print_alphabets {
  my @alphabets = split / /, shift;
  my @out;
  foreach (@alphabets) {
    push @out, $alphabet{substr $_, 0, 1}[ALPHABET_NAME];
  }
  return join ", ", @out;
}

############# FEATURE SUBROUTINES #############

sub help {
  my $subject = defined $_[0] ? lc shift : UNSPECIFIED;
  if (exists $help{$subject}) {
    print $help{$subject};
  } elsif (exists $synonym{$subject} && exists $help{$synonym{$subject}}) {
    print $help{$synonym{$subject}};
  } else {
    print "No help is available on that topic.\n";
  }
}

sub map {
  my $stateList = "";
  $stateList = shift;
  foreach my $r (0 .. $#tile) {
    foreach my $c (0 .. $#{$tile[$r]}) {
      map_print ($stateList, substr $symbols, $tile[$r][$c][SITE_STATE], 1);
    }
    print "\n";
  }
}

sub map_print {
  my $stateList = shift;
  my $char = shift;
  if (defined $stateList) {
    if (-1 != index $stateList, $char) {
      1 == length $stateList ? print SHADE_HIGH : print $char;
    } elsif (0 == index $symbols, $char) {
      print $char;
    } else {
      print SHADE_LOW;
    }
  } else {
    -1 == index $symbols, $char ? print $char : print SHADE_HIGH;
  }
}

sub cities {
  foreach my $r (0 .. $#tile) {
    foreach my $c (0 .. $#{$tile[$r]}) {
      $tile[$r][$c][SITE_NAME] ne INVALID ? print substr $symbols, $tile[$r][$c][SITE_STATE], 1 : $tile[$r][$c][SITE_STATE] == 0 ? print OCEAN_SYMBOL : print SHADE_MEDIUM;
    }
    print "\n";
  }
}

sub city {
  my $state = index $symbols, shift;
  return if ($state eq -1);
  my @cities = city_get ($state);
  foreach (@cities) {
    my ($r, $c) = (shift @$_, shift @$_);
    print "$tile[$r][$c][SITE_NAME] ($tile[$r][$c][SITE_POPULATION] people):\n  " . print_ethnes (ethne_loc ($r, $c)) . "\n  " . print_religions (religion_loc ($r, $c)) . "\n  " . print_languages (language_loc ($r, $c)) . "\n  " . print_alphabets (alphabet_loc ($r, $c)) . "\n";
  }
  @cities == 1 ? print "There is only one city in " : print "There are " . scalar @cities . " cities in ";
  print &state_code ($state, STATE_NAME) . ".\n";
}

sub city_get {
  my $state = shift;
  my @cities;
  foreach my $r (0 .. $#tile) {
    foreach my $c (0 .. $#{$tile[$r]}) {
      if ($tile[$r][$c][SITE_NAME] ne INVALID && $tile[$r][$c][SITE_STATE] == $state) {
        push @cities, [($r, $c)];
      }
    }
  }
  return @cities;
}

sub loc_get {
  my $state = shift;
  my @locs;
  foreach my $r (0 .. $#tile) {
    foreach my $c (0 .. $#{$tile[$r]}) {
      if ($tile[$r][$c][SITE_STATE] == $state) {
        push @locs, [($r, $c)];
      }
    }
  }
  return @locs;
}

sub population {
  my $state = shift;
  my $total = 0;
  foreach (loc_get ($state)) {
    my ($r, $c) = (shift @$_, shift @$_);
    $total += $tile[$r][$c][SITE_POPULATION];
  }
  return $total;
}

sub info {
  my $state = shift;
  if (1 != length $state || -1 == index $symbols, $state) {
    print "Invalid state: $state\n";
    return;
  }
  foreach my $i (0 .. STATE_PARAMETERS - 5) {
    print (("Name\t\t", "Adj.\t\t", "Political system", "Laws\t\t", "Ethnes\t\t")[$i] . ": " . state_symbol ($state, $i) . "\n") if (state_symbol ($state, $i) ne UNSPECIFIED);
  }
  print "Size\t\t: " . area (index ($symbols, $state)) . "\n";
  print "Population\t: " . population (index ($symbols, $state)) . "\n";
  
=pod
  my $code = index $symbols, $state, 1;
  my @friends = friends ($code, 4);
  my @neutral = neutral ($code, -2, 3);
  my @foes = foes ($code, -3);
  if (@friends) {
    print "Friends:\n";
    foreach (@friends) {
      print "  " . state_symbol (substr ($symbols, $_, 1), STATE_NAME) . "\n";
    }
#    print "\n";
  }
  if (@neutral) {
    print "Neutral towards:\n";
    foreach (@neutral) {
      print "  " . state_symbol (substr ($symbols, $_, 1), STATE_NAME) . "\n";
    }
#    print "\n";
  }
  if (@foes) {
    print "Foes:\n";
    foreach (@foes) {
      print "  " . state_symbol (substr ($symbols, $_, 1), STATE_NAME) . "\n";
    }
#    print "\n";
  }
=cut
}

sub census {
  STDOUT->format_name ("LIST");
  my %census;
  foreach (0 .. length $symbols) {
    $census{state_code ($_, STATE_NAME)} = population ($_);
  }
  foreach (sort {$census{$a} <=> $census{$b}} (keys (%census))) {
    $list_state = $_;
    $list_pop = $census{$_};
    write STDOUT;
  }
  STDOUT->format_name ("STDOUT");
}

sub size {
  STDOUT->format_name ("LIST");
  my %size;
  foreach (0 .. length $symbols) {
    $size{state_code ($_, STATE_NAME)} = area ($_);
  }
  foreach (sort {$size{$a} <=> $size{$b}} (keys (%size))) {
    $list_state = $_;
    $list_pop = $size{$_};
    write STDOUT;
  }
  STDOUT->format_name ("STDOUT");
}

sub at {
  my ($y, $x) = (shift, shift);
  my $city = site_loc ($y, $x, SITE_NAME);
  print "$city, " if ($city ne INVALID);
  my $state = state_loc ($y, $x, STATE_NAME);
  if ($state ne INVALID) {
    $state ne (OCEAN)[STATE_NAME] || !defined $_[0] ? print "$state" : print "~~~";
    $state ne (OCEAN)[STATE_NAME] && !defined $_[0] ? print " (population: $tile[$y][$x][SITE_POPULATION])\n" : print "\n";
    unless (defined $_[0]) {
      my @dir = qw/NW N NE W @ E SW S SE/;
      foreach my $dy (-1 .. 1) {
        foreach my $dx (-1 .. 1) {
          my $dir = shift @dir;
          next if ($dir eq "@");
          print "$dir:" . " " x (3 - length $dir);
          at ($y + $dy, $x + $dx, "The existence of this string prevents infinite recursion.");
        }
      }
    }
  } else {
    defined $_[0] ? print "???\n" : print "Off the map.\n";
  }
}

sub near {
  my $state = shift;
  my @neighbors = near_state ($state);
  foreach (@neighbors) {
    print state_symbol (substr ($symbols, $_, 1), STATE_NAME) . "\n" if ($state ne substr $symbols, $_, 1);
  }
}

sub fof {
  print "  ";
  print " " . substr ($symbols, $_, 1) foreach (1 .. length $symbols);
  print "\n";
  foreach my $s1 (1 .. $#opinion) {
    print substr ($symbols, $s1, 1) . ":";
    foreach my $s2 (1 .. $#{$opinion[$s1]}) {
      print " " . relations ($s1, $s2);
    }
    print "\n";
  }
}

sub date {
  print ((980 + int $turn / 52) . "-W" . sprintf ("%02d", (1 + int $turn % 52)) . "\n");
}

sub o {
  my ($s1, $s2) = (shift, shift);
  my ($i1, $i2) = (index ($symbols, $s1), index ($symbols, $s2));
  if ($i1 <= 0 || length $s1 > 1) {
    print "Invalid state: $s1\n";
    return;
  } elsif ($i2 <= 0 || length $s2 > 1) {
    print "Invalid state: $s2\n";
    return;
  }
  if ($i1 == $i2) {
    print &state_symbol ($s1, STATE_NAME) . " is on good terms with itself.\n";
    return;
  }
  relations ($i1, $i2, 1);
  print "===========\n";
  relations ($i2, $i1, 1);
}

sub power {
  my $s = shift;
  my $i = index $symbols, $s;
  if ($i <= 0 || length $s > 1) {
    print "Invalid state: $s\n";
    return;
  }
  print ((area ($i) / state_code ($i, STATE_OFFENSE_A)) . "\n");
}

__DATA__
#         1         2         3         4         5         6         7        
#123456789012345678901234567890123456789012345678901234567890123456789012345678
0                  o        NNN  Nwwwww  t   tt tttRRRRRRRRRRRRRRRRRRRRRRRRRRRR
1               oo           N    Nwwww      tttttRRRRRRRRRRRRRRRRRRRRRRRRRRRRR
2             sssss            dd  dddd       tttRRRRRRRRRRRRRRRRRRRRRRRRRRRRRR
3              sss             dd   dd       ttttRRRRRRRRRRRRRRRRRRRRRRRRRRRRRR
4              sssE             d d     +||ttttttRRRRRRRRRRRRRRRRRRRRRRRRRRRRRR
5          III   ssE            +++++++++||||||||RRRRRRRRRRRRRRRRRRRRRRRRRRRRRR
6         IIII E  EEE        ++++++++++||||||||||RRRRRRRRRRRRRRRRRRRRRR  RRRRRR
7        IIII    EEEEEE    ++++++++++++|||||||||||RRRRRRRRRRRRRRRRRRRR   RRRRRR
8                 EEEEE    ++++++++++++++||||||||~~~~~~RRRRRRRRR mmm    RRRRRRR
9              EEE      ff++++++++++++++++++~~~~~~~~~~~~~RRRRRR    mmmm        
0                  nnnnffff+++++++++++++++++~~~~~~~~~~~~~RRRRR!                
1              BBBBfffffffff+++++++++++++++~~~~~~~~~~~~~~RRRR!                 
2                BBfffffffffbbb++++++++++++~~~~~~~~~~RRRRRRR!!                 
3                  fffffffffbbbb+++++"+V VCCCCCCC!!!!!!!!!!!!!          @@@@@@@
4                   fffffffbbbbb++++++P    VCCrrrrr!!!!!!!!!@@@       @@@@@@@@@
5                   fffffffbbbb+++  +++P      rrrVrr!!!!!!@@@@  @@@@@@@@@@@@@@@
6       lllllll    ffffffffbbbb      +++P''        r!!!!@@     @@@@@@@@@@@@@@@@
7       lllllllllpppppffff        ++    Pca@@@@@@  @!!!!      @@@@@@@@@@@@@@@@@
8       lllllllllUUUUUUUf                   SS@  @   @@@@@     @@@@@@@@@@@@@@@@
9       UUUUUUUUUUUUUU             `          @@       @@@@     @@@@@   @@@@   
0      UUUUUUUUUUUUUU    U         `     yyyy  @      @@@@                   @ 
1      UUUUUUUUUUUUUU                      y                @@@@@         @@@  
2      UUUUUUUUUUUUU          AAAAAAAAAAA                                      
3          UU            AAAAAAAAAAAAAAA                                       
#         1         2         3         4         5         6         7        
#123456789012345678901234567890123456789012345678901234567890123456789012345678

# writing systems
L:Latin alphabet
G:Greek alphabet
g:Glagolitic alphabet
C:Cyrillic alphabet
A:Arabic alphabet
H:Hebrew alphabet
m:Gothic alphabet
f:Elder Futhark
F:Younger Futhark
E:Futhorc
~:Hungarian script

# languages
N:West Norse:F
d:East Norse:F
g:Gutnish:F
m:Crimean Gothic:m
E:English:E
I:Gaelic:L
W:Welsh:L
k:Cornish:L
B:Breton:L
f:French:L
n:Norman:L
b:Burgundian:L
o:Occitan:L
`:Sardinian:L
1:Galician:L
2:Leonese:L
3:Castilian:L
4:Basque:L
5:Aragonese:L
6:Catalan:L
7:Corsican:L
8:Romansch:L
U:Mozarabic:A
A:Arabic:A
L:Latin:L
i:Italian:L
_:Low German:L
^:High German:L
+:Prussian:L
w:Novgorodian:C
R:Russian:C
v:Wendish:L
|:Polish:L
z:Bohemian:L
!:Slavonic:C
G:Greek:G
H:Hebrew:H
~:Hungarian:~

# religions
P:Protestantism:Protestant:Protestant:Protestants
C:Roman Catholicism:Roman Catholic:Catholic:Catholics
O:Eastern Orthodoxy:Eastern Orthodox:Orthodox Christian:Orthodox Christians
J:Judaism:Jewish:Jew:Jews
I:Islam:Muslim:Muslim:Muslims

# ethnes
# not finished
E:generic human:generic humans:generically human:P1f
w:Novgorodian:Novgorodians:Novgorodian:Ow.
R:Kievan:Kievans:Kievan:OR.
!:Yugoslav:Yugoslavs:Yugoslavic:O!.
c:Croatian:Croatians:Croatian:O!g
|:Lechite:Lechites:Lechitic:C|.
v:Wend:Wends:Wendish:Ov.
z:Bohemian:Bohemians:Bohemian:Cz.
f:Frenchman:Frenchmen:French:Cf.
o:Occitanian:Occitanians:Occitan:Co.
J:Jew:Jews:Jewish:JH.

# countries
N:Norway:Norwegian:p:+:E
w:Sweden:Swedish:p:-:E
d:Denmark:Danish:p:+:E
E:England:English:p:+:E9 J
o:Orkney:Orcadian:p:+:E
s:Scotland:Scottish:p:l:E
I:Ireland:Irish:p:l:E
B:Brittany:Breton:p:+:E
f:France:French:p:-:f
n:Normandy:Norman:p:+:E
b:Burgundy:Burgundian:p:+:f
`:Sardinia:Sardinian:r:l:E
p:Pamplona:Pamplonese:p:-:E
l:Leon:Leonese:p:-:E
U:Caliphate of Cordova:Cordovan:p:-:E
A:Fatimid Caliphate:Moorish:p:l:E
y:Sicily:Sicilian:p:l:E
P:Papal States:Papal:p:-:E
V:Venice:Venetian:r:+:E
S:Salerno:Salernan:p:+:E
':Benevento:Beneventan:p:+:E
c:Capua:Capuan:p:+:E
a:Amalfi:Amalfian:p:+:E
":San Marino:Sanmarinese:r:+:E
+:Holy Roman Empire:German:p:+:E
|:Poland:Polish:p:-:|
~:Hungary:Magyar:p:-:E
t:State of the Teutonic Order:Pruthenic:p:+:E
R:Rus:Russian:p:-:R
C:Croatia:Croatian:p:-:c
r:Serbia:Serbian:p:+:c
!:Bulgaria:Bulgarian:p:+:!
@:Byzantine Empire:Byzantine:p:+:E
m:Crimea:Crimean:p:+:E

# Norway
#
# Sweden
#
# Denmark
3:36:Copenhagen
#
# England
8:20:London
6:18:Birmingham
8:18:Bristol
7:17:Caerleon
4:18:Newcastle
6:20:York:z3 J f
#
# Orkney
1:17:Kirkwall
#
# Scotland
4:17:Edinburgh
#
# Ireland
7:11:Waterford
6:13:Dublin
#
# Brittany
11:15:Brest
#
# France
11:23:Paris
18:24:Barcelona
15:20:Bordeaux
15:24:Carcassonne
13:19:Nantes
16:25:Narbonne
12:23:Orleans
13:22:Poitiers
10:26:Rheims
16:23:Toulouse
12:22:Tours
#
# Normandy
10:22:Rouen
#
# Burgundy
14:29:Lyons
16:29:Marseilles
16:30:Nice
#
# Sardinia
20:35:Cagliari
#
# Pamplona
17:19:Pamplona
#
# Leon
17:12:Leon
18:15:Burgos
18:8:Coimbra
17:8:Santiago de Compostela
16:11:Oviedo
#
# Cordova
21:13:Cordova
23:11:Gibraltar
22:15:Grenada
21:7:Lisbon
19:13:Madrid
18:19:Saragossa
22:11:Seville
22:7:Silves
20:14:Toledo
20:20:Valencia
#
# Fatimid Caliphate
22:40:Sousse
#
# Sicily
20:41:Palermo
21:43:Modica
20:44:Syracuse
#
# Papal States
17:40:Rome
15:39:Ancona
14:38:Ravenna
#
# Venice
13:39:Venice
13:41:Parenzo
15:49:Ragusa
#
# Salerno
18:44:Salerno
#
# Benevento
16:41:Benevento
#
# Capua
17:41:Capua
#
# Amalfi
17:42:Amalfi
#
# San Marino
13:37:San Marino
#
# HRE
8:29:Aachen
9:27:Antwerp
11:34:Augsburg
11:31:Basel
14:37:Bologna
8:29:Cologne
15:37:Florence
10:31:Frankfurt
14:34:Genoa
5:32:Hamburg
5:34:Luebeck
15:36:Lucca
9:32:Mainz
13:34:Milan
13:35:Parma
15:36:Pisa
9:40:Prague
10:38:Regensburg
10:30:Strasbourg
7:27:Utrecht
12:37:Verona
11:42:Vienna
10:32:Worms
#
# Poland
6:41:Posen
5:44:Kulm
4:42:Danzig
5:41:Gnesen
8:44:Kattowitz
8:45:Krakow
8:43:Ostrava
8:42:Breslau
#
# Hungary
10:46:Esztergom
10:51:Bihar
11:50:Csanaad
11:55:Gyulafeheervaar
11:46:Veszpreem
#
# Pruthenia
4:43:Malbork
1:47:Riga
0:41:Visby
#
# Rus
6:61:Kiev
0:55:Novgorod:w
#
# Croatia
14:44:Biograd
13:44:Sisak
#
# Serbia
14:49:Ras
15:46:Kotor
#
# Bulgaria
14:59:Preslav
13:49:Belgrade
16:53:Ohrid
13:58:Shumen
#
# Byzantine Empire
15:64:Constantinople
15:73:Angora
19:58:Athens
21:62:Candia
20:55:Mistras
17:43:Naples
16:64:Nicaea
14:62:Pera
21:76:Salamis
18:63:Smyrna
17:44:Sorrento
#
# Crimea
9:68:Doros
#