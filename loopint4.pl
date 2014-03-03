#!/usr/bin/perl -w
use strict;

#April 2005 - John B. Silvestri
#loopint4.pl - an interpreter for Stathis Zachos' loop language

###########
# GLOBALS #
###########

my %variables;
my %iterlock;

my $value_qr=qr/(^\d*$)/; #Just digits
my $var_qr=qr/(^\w\d*$)/; #Single character, followed by zero or more digits
my $op_qr=qr/(\.-|\+|succ|pred)/; #Match ops

###############
# LINEAR CODE #
###############

my @input_block;

if(@ARGV){
	my $input_file=shift;
	open LOOPFILE, "<", $input_file
		or die "Could not open source file: $!\n";
	chomp (@input_block=<LOOPFILE>);
}else{ 
	print "Enter a loop program, terminated with a newline and ^d\n";
	chomp(@input_block=<STDIN>);
}

my $tabstop=0;
my $tabstring="\t" x $tabstop;
my $maincode=join (" ", @input_block);
code_eval($maincode);



###############
# Memory Dump #
###############

print "-"x40 . "\nVariables\n" . "-"x40 ."\n";
foreach (sort keys %variables){
	print "$_ = $variables{$_}\n";
}

###############
# SUBROUTINES #
###############

sub code_eval{
	my $code=shift;
	my $codelen=length($code);
	my ($start,$stop,$pos)=(0,0,0);

	#indent/debug:
	$tabstop++;
	$tabstring="\t" x $tabstop;
	
	while ($start < $codelen){
	
		my $assign_pos=index($code,":=",$start);
		my $for_pos=index($code,"for",$start);
		print "$tabstring DEBUGNEW: a_p: $assign_pos; f_p: $for_pos;\n";
	
		if (first_pos($assign_pos, $for_pos)){ #if 0 < = assign_pos < = for_pos
			my $semi_index=index($code,";",$start); #Find proper end of statement
			$stop=$semi_index > 0 ? $semi_index : $codelen; #Set bounds (works w/o final ';')

			print "$tabstring DEBUGNEW: a_p_a_e: $start;$stop;". ($stop-$start) .";SI:$semi_index\n";
			my $assign_stmt=substr($code, $start,$stop-$start); #Get assignment statement
			assign_eval($assign_stmt); #Evaluate the assignment, setting variable's value

			$start=$stop+1; #Increment starting position for substring searching
		}elsif(first_pos($for_pos, $assign_pos)){ #if 0 < = for_pos < = assign_pos
			#Aaaaaaaaaahhhh....save us all, it's recursion city!
			#Okay, logically - it can't be that bad
			#A for loop in LOOP consists of:
			#
			#for [interator]:=[var/val] to [var/val] do [statement(s)] end
			#
			#Therefore, the parse goes as follows:
			#Read the parts up until 'do' - these are all simple
			#Do the iterator assignment, and set a lock on the variable in an %iterator hash
			#Get the bounds lined up, calling part_eval on the RHS of "to [var/val]"
			#Then, the hell begins
			#A subroutine probably needs to be written, find_end, which finds the end of the
			#statement(s) contained in the for loop.  Doing this will look for nested for
			#loops - if a "for" is found, recursively call find_end.
			#Once the end is found, store code block in a variable, and iterate over bounds,
			#doing a code_eval each time.  (This will in turn do recursion on interior for loops)
			#After iteration is complete, unlock iterator, and _delete_ it

#Picture time
#
#  /$for_pos       /$do_pos
# /    $for_pos+3 /  $do_pos+2
# /   /$iter_pos /  /$code_pos
# |  |          /  /
# |  |       vvv| |
# for i:=1 to e do lalallal for blah end lallllllallala end
#    ^^^^^^| |    ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^| |
#          | \$bound_pos                       $code_end/ |
#          |  $to_pos+2                       find_end()  /
#          \$to_pos                                      /
#                                                  $stop/
#                                            $code_end+2  
#								Swap 2 SE-most entries, and less 3
# String bounds:
# Iterator assignment: $iter_pos, len=$to_pos - $iter_pos
# Bound: $bound_pos, len = $do_pos - $bound_pos
			my $iter_pos=$for_pos+3;
			my $to_pos=index($code, "to",$iter_pos);
			my $bound_pos=$to_pos+2;
			my $do_pos=index($code, "do",$bound_pos);
			my $code_pos=$do_pos+2;

			my $iter_assign=substr($code, $iter_pos, $to_pos - $iter_pos);
			assign_eval($iter_assign);
			my $itername=(split(":=",$iter_assign))[0];
			$itername=~s/\s//g; #strip whitespace
			$iterlock{$itername}=1;
			my $boundary=substr($code, $bound_pos, $do_pos - $bound_pos);
			my $boundval=part_eval($boundary);

			#print "assign|$iter_assign;boundary:$boundary;\n";

			my $code_overflow=substr($code, $code_pos);
			my $end_pos=find_end($code_overflow);#magic hocus-pocus
			my $code_end=$end_pos-3;
			my $code_block=substr($code_overflow,0,$code_end);

			print "$tabstring DEBUG: code block: $code_block\n";
			#print "DEBUG: code overflow: $code_overflow\n";
			foreach($variables{$itername}..$boundval){
				$tabstop--;
				print "$tabstring DEBUG: ${itername}'s iteration no. $_\n";
				#Execute code here
				#print "Buy...spooooonnnnnngguuuuaaarrdddd - for happy kittens.\n";
				code_eval($code_block);
				$variables{$itername} ++;
			}
			delete($iterlock{$itername});
			delete($variables{$itername});
			$start=$code_pos + $end_pos +1; #is this right? something needs to be fixed here.
			$tabstop--;
			#return;
		}else{
			print "Invalid Input\n";
			exit(1);
		}
	
	} #end while loop
} #end sub code_eval

sub find_end{
	my $fe_string=shift;

	#This is not easy
	#Concepts: We may have nested and/or adjacent for loops in the main for loop block
	#Therefore, we must have a way to find the end of the main code block, such that the
	#ugliness cited above will be executed the correct number of times
	#
	#General idea: Check for 'end' before 'for'  If true, 'end' has been found
	#If false, then there exists one or more for loops before the 'end' we are interested in
	#Maintaining a list of unmatched 'for' items ought to keep a do/while loop running until
	#closing 'end' statements are found.  No backtracking will take place - if a for/end pair
	#is found, all index() calls are made to the right of the last successful 'end.' Also, pop 'for.'
	#If 'for' found before 'end,' push to list (w/index?), and set this 'for' as new left bound.
	#
	#Return: location of /last/ 'end' - the one that caused the list to become unpopulated.
	#n.b. Push initial value to list to keep it running, as end will always perform a pop().
	
	my $fe_pos=0;
	my ($fe_for_p,$fe_end_p)=(0,0);
	my @fe_for_stack;
	push(@fe_for_stack,$fe_pos);
	do{
		$fe_end_p=index($fe_string,"end",$fe_pos);
		$fe_for_p=index($fe_string,"for",$fe_pos);
			#print "DEBUG: FFS: @fe_for_stack\n";
		if(first_pos($fe_end_p,$fe_for_p)){
			$fe_pos=$fe_end_p+3;
			pop(@fe_for_stack);
			#print "DEBUG: FP->FEP: $fe_pos\n";
			#print "DEBUG: FP:FFS: @fe_for_stack\n";
		}elsif(first_pos($fe_for_p,$fe_end_p)){
			push(@fe_for_stack,$fe_for_p);
			$fe_pos=$fe_for_p+3;
			#print "DEBUG: FP->FFP: $fe_pos\n";
		}else{ #this shouldn't happen
			die ("For loop error?\n");
		}
	}while (@fe_for_stack);
	return $fe_pos;
} #end sub find_end

sub assign_eval{
	my $assign_stmt=shift;
	print "$tabstring DEBUG: A_S: $assign_stmt\n";
	my @assign_parts=split(":=",$assign_stmt);
	my ($a_lhs,$a_rhs)=@assign_parts;
	$a_lhs=~s/[;\s]//g; #strip whitespace (and semicolons)
	if (exists $iterlock{$a_lhs}){
		die "Cannot perform assignment on iterator\n";
	}
	if ($a_rhs=~/$op_qr/){
		$variables{$a_lhs}=st_eval($a_rhs);
	}else{
		$variables{$a_lhs}=part_eval($a_rhs);
	}
}

sub st_eval{
	my $stmt=shift;
	my @parts=split(/$op_qr/, $stmt);
	$stmt=~m/$op_qr/; #Capture op to $1
	my $op=$1;
	if($op eq ".-"){
		my($lhs,$rhs)=@parts[0,2];
		my $val1=part_eval($lhs);
		my $val2=part_eval($rhs);
		my $result=($val1 >= $val2) ? $val1-$val2 : 0;
		return $result;
	}elsif($op eq "+"){
		my($lhs,$rhs)=@parts[0,2];
		my $val1=part_eval($lhs);
		my $val2=part_eval($rhs);
		my $result=$val1+$val2;
		return $result;
	}elsif($op eq "succ"){
		my $rhs=$parts[2];
		my $val1=part_eval($rhs);
		my $result=$val1+1;
		return $result;
	}elsif($op eq "pred"){
		my $rhs=$parts[2];
		my $val1=part_eval($rhs);
		my $result=($val1 >= 0) ? $val1-1 : 0;
		return $result;
	}
} #end sub st_eval

sub part_eval{
	my $part=shift;
	$part =~ s/\s//g; #Strip whitespace
	if ($part=~m/$value_qr/){
		my $value=$1;
		return $value;
	}elsif($part=~m/$var_qr/){
		my $varname=$1;
		if (exists $variables{$varname}){
			return $variables{$varname};
		}else{
			die "Variable $varname has not been initialized\n";
		}
	}
} #end sub part_eval

sub first_pos{
	my ($a_in,$b_in)=@_; #given a and b, return boolean of which comes first (and is >=0)
	#if 0 < = a_in < = b_in
	if ($a_in == -1){ #if "a" isn't there -> definitely not it
		return 0;
	}elsif ($b_in == -1){ #'b' isn't there -> 'a' wins handsdown (exists, and must be greater)
		return 1;
	}elsif ($a_in < $b_in){ #'a' really comes before 'b'
		return 1;
	}else{ # 'b' came first
		return 0;
	}
}
