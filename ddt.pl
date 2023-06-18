class GrammarTrace
{
has $.name ;
has $.result is rw ;
has @.sub_traces ;
}

role TracedGrammarTree
{
my (GrammarTrace $tree, GrammarTrace @stack) ;

method tracer($obj, $name, $method) 
	{
	return -> $c, |args
		{
		# reset between grammar matchings 
		@stack = $tree = GrammarTrace.new(:name('ROOT')) if @stack.elems <= 1 ;

		my $trace = GrammarTrace.new(:$name) ;

		@stack[*-1].sub_traces.push: $trace ;
		@stack.push: $trace ;

		# Call rule and assign the result in the current trace object.
		@stack[*-1].result = $_ := $method($obj, |args);

		@stack.pop ;

		$.dump_trace_tree($obj, $tree.sub_traces[0]) if @stack.elems == 1 ; 

		$_ # return result
		}
	}
}
 
role TracedGrammarTreeDumperDDT
{
use Terminal::ANSIColor;
use Data::Dump::Tree ;
use Data::Dump::Tree::DescribeBaseObjects ;
use Data::Dump::Tree::ExtraRoles ;
use Data::Dump::Tree::Enums ;

my role DDTR::GrammarTrace does DDTR::StringLimiter
	{
	has $.string_limit is rw = 50 ;
	multi method get_header (Str:D $s) { $.limit_string($s.perl, $.string_limit) }

	multi method get_header (GrammarTrace:D $t) 
		{ ($t.result.MATCH ?? $t.result.MATCH.Str // '' !! '', '.MatchTrace')}

	multi method get_elements (GrammarTrace:D $t) 
		{ $t.sub_traces.map: { colored(.name, .result.MATCH ?? 'green' !! 'red'), ' ', $_} }
	}

method dump_trace_tree($grammar, GrammarTrace $trace)
	{
	dump(	$trace,
		title => colored($trace.name, $trace.result.MATCH ?? 'green' !! 'red') 
			~ colored(' (' ~ $grammar.perl.subst('.new', '') ~ ')', 'blue'),

		display_info => False,
		does =>	(
			 DDTR::FixedGlyphs,
			 #DDTR::UnicodeGlyphs,
			 DDTR::GrammarTrace,),
		) ; 
	}
}

role TracedGrammarTreeDDT does TracedGrammarTree does TracedGrammarTreeDumperDDT {}

role TraceGrammerDefaultTracer
{
method tracer($obj, $name, $methode){ return -> $c, |args { $methode($obj, |args)} }
}

my class TracedGrammarHOW is Metamodel::GrammarHOW does TracedGrammarTreeDDT
{
method find_method($obj, $name) 
{
my $meth := callsame;

return $meth if $meth.WHAT.^name eq 'NQPRoutine';
return $meth unless $meth ~~ Any;
return $meth unless $meth ~~ Regex;
return $.tracer($obj, $name, $meth) ;
}
    
method publish_method_cache($obj) { } # Suppress this, so we always hit find_method.
} # class

# Export this as the meta-class for the "grammar" package declarator.
my module EXPORTHOW { }
EXPORTHOW::<grammar> = TracedGrammarHOW;

