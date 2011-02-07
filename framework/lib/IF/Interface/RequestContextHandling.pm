package IF::Interface::RequestContextHandling;

# Placing this code here is a bit of a stop-gap
# solution while I'm porting the session-handling
# over to use various backends.  It will probably
# not live here very long, but you'll never need
# it so who cares?

use strict;

sub addRenderedComponent {
	my $self = shift;
	my $component = shift;
	my $pageContextNumber = $component->renderContextNumber();
	my $componentName = $component->componentName();
	$self->{_renderedComponents}->{$componentName}->{$pageContextNumber}++;
	$self->{_renderedPageContextNumbers}->{$pageContextNumber}++;
}

sub didRenderComponentWithPageContextNumber {
	my ($self, $pcn) = @_;
	#IF::Log::debug("Checking if we rendered component with context number $pcn");
    if ($self->{_renderedPageContextNumbers}->{$pcn} > 0) {
        #IF::Log::debug(" .........----> Yep.");
        return 1;
    }
	my $keys = [keys %{$self->{_renderedPageContextNumbers}}];
	my $re = $pcn.'L[0-9_]+$';
	
	foreach my $k (@$keys) {
		if ($k =~ /^$re/) {
		    #IF::Log::debug(" .........----> Yep, $k");
		    return 1;
		}
	}
	#IF::Log::debug(" .......-----> Nope.");
	#IF::Log::dump($self->{_renderedPageContextNumbers});
	return 0;
}

sub didRenderComponentWithName {
	my $self = shift;
	my $componentName = shift;
	#IF::Log::debug("Checking if we rendered component with name $componentName");
	my $n = $self->{_renderedComponents}->{$componentName};
	if ($n) {
	    #IF::Log::debug(" .....-----> Yep.");
	    return 1;
	}
	#IF::Log::debug(" ......-----> Nope.");
	$self->dumpRenderedComponents();
	return 0;
}

sub pageContextNumbersForComponentWithName {
	my ($self, $componentName) = @_;
	return $self->{_renderedComponents}->{$componentName};
}

sub pageContextNumberForCallingComponentInContext {
	my $self = shift;
	my $componentName = shift;
	my $context = shift;
	return undef unless $self->didRenderComponentWithName($componentName);
	foreach my $pageContextNumber (keys %{$self->{_renderedComponents}->{$componentName}}) {
		#IF::Log::debug("Rendered $componentName with number $pageContextNumber");
		foreach my $key ($context->formKeys()) {
			next unless $key =~ /^[0-9_]+$/;
			return $pageContextNumber if ($key =~ /^$pageContextNumber/);
		}
	}
	return undef;
}

sub dumpRenderedComponents {
	my $self = shift;
	IF::Log::dump($self->{_renderedComponents});
}

1;