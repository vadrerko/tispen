use utf8;
use strict;
use Tcl;
use Text::Template; 
use List::Util;
use Time::HiRes();
use POSIX('floor');

# -------------------------------------------------------------------------
# 1. INITIALIZE THE INTEGRATED HADRON ENVIRONMENT
# -------------------------------------------------------------------------
# We spin up the embedded Tcl interpreter instance.
# Perl acts as the supervisor process holding the persistent memory space.
my $int = Tcl->new();
$int->Init();

# Global session configurations matching the core vispen ethos
our $DBH_MAIN  = undef; # Persistent $::dbh equivalent for database connections
our $DBH_ALT   = undef; # Persistent $::dbh1 equivalent for alternative routers
our $UNTEMPLATE_PREDICATE = 1; # Mimics $vim::untemplatep behavior

$vim::untemplatep  = 0; # perform in-memory untemplate of lines before cursor?
$vim::width        = 80;  # table width
$vim::anchorp      = 0; # add anchor with elapsed time after each request
$vim::title_rows   = 10; # max number of rows in table title

# -------------------------------------------------------------------------
# 2. VIM TO TCLED BRIDGE API (ABSTRACTION LAYER)
# -------------------------------------------------------------------------
# We replace Vim's internal C-bindings ($curbuf->Get, append, etc.) 
# with native Tcl mutations targeting the active text data in tcled.

sub tcled_get_current_line {
    # In tcled, the file buffer is stored inside a Tcl list variable named '$BUFFER'.
    # The active line index is stored in '$bufRow'. We safely fetch it via Eval.
    return $int->Eval('lindex $BUFFER $bufRow');
}

sub tcled_get_line {
    my $row = $_[0] - 1;
    return $int->Eval('lindex $BUFFER ' . $row);
}

sub tcled_remove_line {
    return $int->Eval('set BUFFER [lreplace $BUFFER ' . $_[0] . ' ' . $_[0] . ']');
}

sub tcled_coumt_lines {
    return $int->Eval('llength $BUFFER');
}

sub tcled_insert {
    my $row = $_[0] +1;
    my $text_to_insert = $_[1];
    $int->SetVar('var', $text_to_insert);
    return $int->Eval('set BUFFER [linsert $BUFFER ' . $row . ' $var]');  # TODO improve
}

sub tcled_get_entire_buffer {
    # Fetches all lines currently loaded into the editor memory as a Perl array.
    # Essential for multiline block processing (=sql / =Cut blocks) and untemplating.
    my @buffer = $int->SplitList($int->Eval('set BUFFER'));
    return @buffer;
}

sub tcled_insert_after_current {
    my ($text_to_insert) = @_;
    
    # Pass the text payload cleanly into the Tcl layer via a controlled variable
    $int->SetVar('hadron_payload', $text_to_insert);
    
    # Execute structural mutation within tcled context:
    # 1. Split the incoming text payload into clean individual rows.
    # 2. Increment the row cursor position to move past the execution trigger point.
    # 3. Inject rows sequentially into the list via [linsert].
    # 4. Trigger editor state redraw flags ('modified' status and 'handleRedraw forced').
    $int->Eval(q{
        set rows [split $hadron_payload "\n"]
        foreach row $rows {
            incr bufRow
            set BUFFER [linsert $BUFFER $bufRow $row]
        }
        set modified 1

        handleRedraw forced
    });
}

sub toyspen_status {
    $int->invoke('status', $_[0]=~s/\n//gr);
    toyspen_redraw();
}

sub toyspen_redraw {
    $int->invoke('handleRedraw','forced');
}

# -------------------------------------------------------------------------
# 3. PORTED VISPEN ENGINE EXECUTIVE HOOK
# -------------------------------------------------------------------------
# This sub replaces Vim's traditional "execute_here()" handler.
# When the user invokes this trigger, control transfers smoothly to Perl.

sub hadron_vispen_execute_here {
    my $row = $int->GetVar('bufRow');
    my $col = $int->GetVar('bufCol');
    my $cmd = $int->Eval('lindex  $BUFFER $bufRow');
    #toyspen_status("[$row $col] [$cmd] (@_)");

    my $arg = $_[3] || 0;
    # run current line
    #my ($row,$col) = $::curwin->Cursor;
    #my $cmd = $::curbuf->Get($row);

    my $row0=$row;

    if ($cmd =~ m/^([?c]?)( *)$/) {
	# if empty line - then suggest something to user
	if ($row>0) {$row--}
	if ($1 eq '?') {
	    $row = tcled_insert_after_current(<<'EOS');
# press <F9> on empty line to get predefined lines for $::dbh initialization
# or on a line containing only '?' to get this help
# or on a line containing only 'c' to get config which you could edit
EOS
	} elsif ($1 eq 'c') {
            my $e = '';
	    $row = tcled_insert_after_current(<<"EOS");
$e\$vim::untemplatep  = $vim::untemplatep; # perform in-memory untemplate of lines before cursor?
$e\$vim::width        = $vim::width;  # table width
$e\$vim::anchorp      = $vim::anchorp; # add anchor with elapsed time after each request
$e\$vim::title_rows   = $vim::title_rows; # max number of rows in table title
$e\$vim::html_save_to = '$vim::html_save_to'; # file name where HTML output is to be saved
EOS
	} else {
	    $row = tcled_insert_after_current($vim::initial_lines || <<'EOS');
{{{ # vi: syn=perl
# here perl code executed each time on executionn for 'untemplate' phase - but
# if $vim::untemplatep flag is ON
''
}}}\
=ie

use DBI; $::dbh = DBI->connect("dbi:SQLite:dbname=try-1.sqlite","","");

# config:
$vim::untemplatep = 0
$vim::width = 123;

# for <F9> - SQL execution:
select 1 as n
=cut

select "a" a,"b" as b union all select 'Peter','{{{"a"x1000}}}'

below is 'crazy'-generated SQL:
=Sql g/f=+
{{{join " union all\n", map {"select 'value $_' as v,".++$::cnt } 'a'..'rz'}}}
=Cut

=Sql
WITH RECURSIVE generate_series(value) AS (
    SELECT 1 
    UNION ALL 
    SELECT value + 1 FROM generate_series WHERE value < 100
)
SELECT value FROM generate_series
=Cut

=perl
use Data::Dumper; Dumper \%::r
=Cut
EOS
	}
	return;
    }
my $msg = '';
eval {	

    if ($vim::untemplatep) {
	# get lines before current point to 'untemplate'
	my $pretext = join "\n", tcled_get_line(0 .. $row-1);
	$pretext =~ s/^=(?:sqlm?|perl)\b.*?(?:(?:^=cut *\n)|\Z)//sigm; # do not untemplste =sql/=perl ... =cut
	$pretext =~ s/^=(?:ignore_everywhere|ie|sqlm?|Sqlm?|sQlm?|sqLm?|sQLm?|perl|Perl|pErl|PERL)\b.*?(?:(?:^=cut *\n)|\Z)//sgm;
	$Text::Template::ERROR = '';
	my ($del0, $del1, @delims) = ('{','}');   # delimiters {{{...}}} or {{...}} or none/default
	if ($pretext=~/^(\{\{\{?)/) {
	    $del0 = $1;
	    $del1 = '}'x length($1);
	    @delims = (DELIMITERS=>[$del0, $del1]);
	}
	my $dummy_s = Text::Template->new(
	    TYPE   => 'STRING',
	    SOURCE => ($arg==1?"$del0$::reset$del1":($arg==100?"$del0$::super_reset$del1":"")) . $pretext,
	    @delims,
	    BROKEN => sub{die "error in template: [$Text::Template::ERROR] \$@=$@, please recheck!"},
	)->fill_in();
	if ($Text::Template::ERROR) {
	    VIM::Msg("\$Text::Template::ERROR=[$Text::Template::ERROR]","ErrorMsg");
	    return;
	}
    }

    #=sql
    #select {{{1+1}}}
    #=cut
    #{code:sql}
    #select 2
    #{code}
    #||2||
    #|2|

    #=sql name/f=j
    #select {{{1}}}
    # --!!! <-- even not shown in {code:sql}...{code} (super-invisible comments)
    #=cut
    #{code:sql}
    #select 1
    #-- 1
    #{code}
    #||1||
    #|1|

    #=ie
    # ...
    # =ie/=ignore-everywhere will not be shown in the untemplated result
    #=sql name/f=-
    #select {{{1}}} {{{" union all select 2" x 100}}}
    #=Cut
    #{code:sql}
    #select 1  union all select 2 union all select 2.......
    #{code}
    #-- 101 rows
    #...
    #=cut

    my $jira_syntax=0;
    my $x0 = List::Util::first {tcled_get_line($_) =~ /^(?:(?: *$)|\}|=)/} reverse 1 .. $row;
    my $x1 = $row;
    my $sqlname = '';
    my ($ifperl, $perlnostrict, $perlshowcode, $perluntemplate) = (($arg==5?1:0),0,0,0);
    my ($ifsqlselect,$ifsql1) = (0,0);
    my ($ifsqlmulty) = (0);
    my $need_remove_old = 1;

$msg.= "arg=$arg";
    if (defined $x0 && tcled_get_line($x0) =~ /^=(sqlm?|Sqlm?|sQlm?|sqLm?|sQLm?|perl|Perl|pErl|PERL)\b\s*(.*?)\s*$/) {
        # sqL, sQL - so to avoid jirasyntax
        # sQl, sQL - $::dbh1
        # pErl - untemplate then perl
        # PERL - same as perl but in 'no strict;' mode
        my $verb=$1;
$msg.= "x=$1,";
        $ifperl = lc($verb) eq 'perl' ? 1 : $ifperl;
        $perlshowcode = $verb eq 'Perl' || $verb eq 'pErl';
        $perluntemplate = $verb eq 'pErl';
        $perlnostrict = $verb eq 'PERL';
        if (lc($verb) eq 'sqlm') {$ifsqlmulty=1;$ifsqlselect=1;$verb=substr($verb,0,3);}
        $ifsqlselect = 1 if $verb eq 'Sql';
        $ifsql1 = 1 if ($verb eq 'sQl' or $verb eq 'sQL' );
        $jira_syntax = $ifperl ? 0 : ($verb ne 'sqL' and $verb ne 'sQL');
        $sqlname = $2=~s/\s.*$//r; # after space there could be comment - strip it
        $x1 = List::Util::first {
                tcled_get_line($_) =~ /^=cut/i
            } $row+1 .. tcled_coumt_lines();
        die "no =cut but =sql!" unless defined $x1;
        $cmd = join("\n",tcled_get_line($x0+1 .. $x1-1));

        # remove from $x1+1 until /^\s*$/ or EOF or next =something or '{{{'
        while ($x1+1 <= tcled_coumt_lines() && tcled_get_line($x1+1) !~ /^(?:(?: *$)|=|\{\{\{)/) {
            tcled_remove_line($x1+1);
        }
        $need_remove_old = 0;
    }
    elsif ($arg==2) {
        # $cmd is up to '' down to '' or /^--/
        $x1 = List::Util::first {
                tcled_get_line($_) =~ /^(?:\||(?: *$)|=|--|\}|\(:|[┌╞└│])/
            } $row+1 .. tcled_coumt_lines();
        $x1 = tcled_coumt_lines() unless defined $x1;
        $cmd = join("\n",tcled_get_line((defined $x0?$x0+1:$row) .. $x1-1));
        $x1--;
        $row=$x1;
    }
    
$msg.= "r,";
    my $lid = $sqlname =~ s/\/lid=(\w+)\b// ? $1 : '';

    $cmd =~ s/^ *--!.*(?:\n|\Z)//mg unless $ifperl; # remove super-invisible-comments

    # remove old 'answer' lines - they-are all prefixed with -- or with MariaDB [...] or /?what else?/
    while ($need_remove_old && tcled_get_line($row+1) =~ /^(?:--|\||\(:|MariaDB \[|[┌╞└│])/) { # TODO utf8 for ┌╞└│
        my $r = tcled_get_line($row+1);
        tcled_remove_line($row+1);
    }

    ## run the task
    my $cmd1 = $ifperl? $perluntemplate ? Text::Template::fill_in_string($cmd, ENCODING=>'UTF8',DELIMITERS=>['{{{','}}}']) : $cmd
                      : $cmd=~/^---#(.*)$/ ? $1 : 
                        Text::Template::fill_in_string($cmd, ENCODING=>'UTF8',DELIMITERS=>['{{{','}}}']);
    my $cmd1_sav = $cmd1;

    my $precmd1 = $sqlname =~ /^#/ ? "$::sqlcnt. ":'';

$msg.= "r,";
    # now put several lines prefixing these with ||
    if ($jira_syntax) {
        my $x10=$x1;
        tcled_insert($x1++, "{code:sql|borderColor=#00DD00}");
        for(split(/\n/,$precmd1.$cmd1)){tcled_insert($x1++, $_);}
        tcled_insert($x1++, "{code}");
        #VIM::DoCommand("normal ${x10}Gjzf".($x1-$x10-1)."jzok");
    } else {
        if (!$perluntemplate and $cmd1_sav ne $cmd) { # if untemplated has changed
            for(split(/\n/,$precmd1.$cmd1)){tcled_insert($x1++, "---$_");}
        }
    }

$msg.= "a,".tcled_coumt_lines.':';
    my $t0 = [Time::HiRes::gettimeofday()];
    my $dbh = $ifsql1 ? $::dbh1 : $::dbh;
    my $res='';
    if ($ifperl) {
$msg.= "[cmd1=$cmd1]";
        $res = ($perlshowcode ? "{code:perl|borderColor=#0000DD}\n".($cmd1=~s/^.*?###.*?(?:\n|\Z)//grm=~s/^\{code[^{}]*\} *\n//grm=~s/\n+$//r)."\n{code}\n{code:none}\n": '') .
            (eval ''.($perlnostrict ? "no strict;" : "") . $cmd1) .
            ($perlshowcode ? "{code}\n": '');
        if ($@) {$res.="ERROR: [$@]\n"}
        my $elapsed = Time::HiRes::tv_interval($t0, [Time::HiRes::gettimeofday()]);
        $res .= "{anchor:perl_xxx_$elapsed}\n" if $vim::anchorp;
    } elsif (substr($cmd1,0,1) eq '#') {
	# do nothing. TODO: document this!
    } elsif ($ifsqlselect || $cmd1=~/^(?:explain\s*)?(select|show|with|values)/i) {
        my $fe_cmd=$1;
        if ($sqlname eq '' and $cmd1=~/^select\s*\/\*([\w\-!\/\=+]+)\*\//i) {$sqlname=$1}
        my $format = ($jira_syntax || $fe_cmd eq 'Select' || $fe_cmd eq 'Show') ? 'j'
            : $fe_cmd eq 'sElect' ? 'T' : $fe_cmd eq 'seLect' ? 't' : $fe_cmd eq 'selEct' ? 'h'
            : $fe_cmd eq 'seleCt' ? 'x' : '+';
        if ($sqlname =~ s/\/f=([\w+\-])$//) {$format=$1}
        my $fv = {
                h=>["<table><tr><th>",'</th><th>','</th></tr>','<tr><td valign="top">','</td><td valign="top">','</td></tr>',"</table>\n"],
                O=>["(:table border=\"1\":)\n(:row:)(:hcell:)",'(:hcell:)','','(:row:)(:cell align=left:)','(:cell align=left:)','',"\n(:tableend:)"],
                o=>['||','||','||','||','||','||',''],
                j=>['||','||','||','|','|','|',''],
                t=>['-- ',',','','--',',','',''],
                T=>['-- ',"\t",'','--',"\t",'',''],
            } -> {$format};

        my @cmd2 =  ($ifsqlmulty ? split("/\\*\\*/\n",$cmd1) : ($cmd1));
$msg.= "t,";
        for my $cmd2 (@cmd2) {
            my $sth = $dbh->prepare($cmd2) or die "can't prepare [$cmd2]: " . $dbh->errstr();
            $sth->execute() or die "can't execute [$cmd2]: " . $sth->errstr();
            my @names = @{$sth->{NAME} || []};
            my $aref = ($dbh->errstr?[]:$sth->fetchall_arrayref()) or die "can't fetchall [$cmd2]: " . $sth->errstr();
            if ($format eq '+') {
		# TODO: use Term::Table
                my @w = map {
                        my $c=$_;
                        List::Util::max 1+0*length($names[$c]), map {length($aref->[$_]->[$c])} 0 .. $#$aref
                    } 0 .. $#names;
                my @w0 = @w;
                my $tot = $#w+1 + List::Util::sum @w;
                if ($tot > $vim::width) {
                    # ...и пересчитать ширину
                    @w = map {
                            my $c=$_;
                            List::Util::max 1+0*length($names[$c]), map {length($aref->[$_]->[$c])} 0 .. $#$aref
                        } 0 .. $#names;
                    $tot = $#w+1 + List::Util::sum @w;
                    my $wrap_factor = $tot/($vim::width-$#w+2);
                    @w0 = map { POSIX::floor($_/$wrap_factor) || 1} @w;
                }
                my $tot0 = $#w+1 + List::Util::sum @w0;
                my $cap = "+".(join "+", map {'-'x $w0[$_]} 0 .. $#w) . "+\n";
                #┌─┐
                #├─┤
                #└─┘
                my $captop = $cap =~ tr{-+}{─┬}r =~ s/^┬/┌/r =~ s/┬$/┐/r;
                my $capm   = $captop =~ tr{┌┬┐─}{╞╪╡═}r;
                my $capb   = $captop =~ tr{┌┬┐}{└┴┘}r;
                my $bar = "│"; #"|";
                # formatting char-table
                # my $titlerows = 1+List::Util::max map {int(length($names[$_])/$w0[$_])} 0 .. $#$aref; # TODO
                $res .=
                    $captop .  #┌─┐
                    (   # field names in title, with line wrapping
                        join "", map {
                            my $line = $_;
                            $bar . (join $bar, map {
                                # line № $line in title row
                                sprintf "%$w0[$_].$w0[$_]s", substr($names[$_],$line*$w0[$_])
                            } 0 .. $#w) . "$bar\n"
                        } 0 .. List::Util::min List::Util::max (0, map {int(length($names[$_]) / $w0[$_])-1} 0 .. $#w), $vim::title_rows
                    ) .
                    $capm .    #├─┤
                    # lines themselves, with wrapping
                    join ("", map {
                      my $a=$_;
                      if ($tot > $vim::width) {
                          # wraping factor
                          # ideally we should consider field types, should allocate some space to numbers and remaining
			  # should be spread proportionally
                          # here - simplified way
                          # distribute proportionally to maximal width to the width $vim::width-$#w+2
                          #
                          my @writeto;
                          # write string $str width $width into scalar $writeto starting from $pos
                          for (my $i=0; $i<=$#w; $i++) {
                              my ($str,$width,$totwidth) = ($a->[$i]=~y{\n}{ }r, $w0[$i], $tot);
                              my $curpos = 0;
                              my $curline = 0;
                              my $pos = $i+List::Util::sum0 @w0[0 .. $i-1];
                              while ($curpos < length($str)) {
                                  push @writeto, (' ' x ($tot0+1)) . "\n" if $curline > $#writeto;
                                  substr($writeto[$curline],$pos,$width+2) = sprintf " %${width}.${width}s ", substr($str,$curpos);
                                  $curpos += $width;
                                  $curline++;
                              }
                          }
                          for (@writeto) {my $curpos=0;for my $colw (@w0){substr($_,$curpos+=$colw+1,1)=$bar}substr($_,0,1)=$bar}
                          join "", @writeto
                      } else {
                          $bar.(join $bar, map {sprintf "%$w[$_]s",$a->[$_]} 0 .. $#w)."$bar\n"
                      }
                    } @$aref) .
                    $capb;     #└─┘
            } elsif ($format eq 'x') {
                $res .= "{code:none}\n" . join("", map {
                          my $cnt=0;
                          my $x = join "\n", map{$names[$cnt++] . " : " .s/\n/\\n/gr=~s/^$/ /r} @$_;
                          $x  . "\n";
                      } @$aref)
                      . "{code}\n";
            } else {
                $res .= ( $format eq '-' ? "-- ".($#$aref+1)." rows" :
                  (
                    # formatting requested format
                  $fv->[0] . join($fv->[1],@names) . "$fv->[2]\n" .
                  join("", map {
                          my $x = join $fv->[4], map{s/\n/\\n/gr=~s/^$/ /r} @$_;
                          $fv->[3] . $x  . $fv->[5] ."\n"
                      } @$aref) .$fv->[6]
                  )
                );
            }
            $res .= "\$DBI::errstr=$DBI::errstr" if $DBI::errstr;
            if ($format eq 'h' and $vim::html_save_to) {open my $fh,">$vim::html_save_to";print $fh $res}
            if ($sqlname) {
                $sqlname = "#$::sqlcnt" if $sqlname eq '#';
                $::res{$sqlname} = $res;
                $::r{$sqlname} = $aref;
                $::colnames{$sqlname} = \@names;
            } else {
                # name not specified - then generate name, so to allow for easier navigation (TODO - document this technique)
                $sqlname = ($ifsql1 ? '17' : 't') . '_' . join('_',@names) =~s/\W+//gr;
                my $elapsed = Time::HiRes::tv_interval($t0, [Time::HiRes::gettimeofday()]);
                $res .= "{anchor:${sqlname}_$elapsed}\n" if $vim::anchorp; # - for jira. TODO for other formats
                $::r{$sqlname} = 1; # TODO - cleanup
            }
        }
    } else {
        my $sql = $cmd1; # otherwise we should do ENCODING=>'UTF8' on Text::Template
        my $ret = "$vim::mariadb [".$dbh->do($sql) .
		($lid ? " id=".($::id{$lid} = $dbh->last_insert_id(undef,undef,undef,undef)):"")."]> _" .
                ($DBI::errstr ? "\$DBI::errstr=$DBI::errstr": "");
        $res = ($jira_syntax?"{code:none}\n":"") . $ret . ($jira_syntax?"\n{code}":"");
    }
$msg.= "[res=$res]";
    my $dr=0;
    $vim::elapsed = Time::HiRes::tv_interval($t0, [Time::HiRes::gettimeofday()]);
    for (split /\n/, $res) { # appends a line(s)
$msg.= "[$dr]";
        tcled_insert($x1+$dr++, $_);
    }
    if ($dr > 0) {
	# fold
        #TODO $::curwin->Cursor($x1,1);
        #TODO VIM::DoCommand("normal jzf".($dr-1)."jzok") if $dr>1;
    }
    #TODO $::curwin->Cursor($row0,$col);
};

if ($@) {
toyspen_status($msg."error: $@");
}
else {
toyspen_status($msg."done.");
}

	$int->SetVar('bufRow',$row0);
	$int->SetVar('bufCol',$col);
	toyspen_redraw();

    #VIM::DoCommand("redraw");
    #TODO VIM::Msg("done ($vim::elapsed) $cmd1", "Comment");
}

# Register our entrypoint command within the Tcl interpreter space.
# tcled can now call this execution bridge using the command word: 'vispen_trigger'
$int->CreateCommand('vispen_trigger', \&hadron_vispen_execute_here);

# -------------------------------------------------------------------------
# 4. BOOTSTRAPPING THE TCLED SOURCE ENGINE
# -------------------------------------------------------------------------

# Run the text editor code inside our stateful engine environment.
# Make sure to map your key binding directly inside the main loop of your tcled file:
# Example inside tcled:
#   if {$keybuffer == "\[20~"} { vispen_trigger; set keybuffer ""; continue }

# tcled wants these vars:
$ENV{SHELL} = '123';
#$int->SetVar2('args', $text_to_insert);
$int->Eval("set argv [list 1 2 3]");
$int->Eval('source tcled');

