package IF::Interface::Notifications;

use strict;

my $_NOTIFICATION_ORDER_FOR_CLASS = {};

sub _notificationOrderForInstanceOfClassNamed {
	my ($className, $visitedClassnames) = @_;

	$visitedClassnames ||= {};
	
	# cache this stuff so we don't need to traverse the @ISA tree every
	# time a notification is sent.
	if ($_NOTIFICATION_ORDER_FOR_CLASS->{$className}) {
		$visitedClassnames->{$className} = 1;
		return $_NOTIFICATION_ORDER_FOR_CLASS->{$className};
	}

	{
		no strict 'refs';
		my $i = [@{$className."::ISA"}];
		return [] unless IF::Log::assert($i && IF::Array::isArray($i), "$className is not an array of class names");
		$visitedClassnames->{$className} = 1;
		my $all = [];
		foreach my $c (@$i) {
			next if ($visitedClassnames->{$c});
			push (@$all, @{_notificationOrderForInstanceOfClassNamed($c, $visitedClassnames)});
		}
		my $no = [$className, @$all];
		$_NOTIFICATION_ORDER_FOR_CLASS->{$className} = $no;
		return $no;
	}
}


# Holy shit, this is dangerous... but in a sense it's no different
# than adding a category to NSObject in OSX...
package UNIVERSAL;

# Notifications are just special method calls that bubble up
# through the inheritance hierarchy in a depth-first manner
# (just like a regular call) but do not terminate the call if
# an instance of the method is found and executed; instead,
# every class in the hierarchy is given a chance to invoke
# the method.  This means that a single notification sent to
# an object could cause numerous instances of the method call to
# be executed.
sub invokeNotificationFromObjectWithArguments {
	my ($self, $notification, $object, @arguments) = @_;
	
	# questions:
	# * how do we pass $object in effectively?  Right now it
	#   is required for all notifications.
	# * do we check if $self respects the Notifications interface?	
	#   return unless (isa($self, "IF::Interface::Notifications"));
	
	my $no = IF::Interface::Notifications::_notificationOrderForInstanceOfClassNamed(ref($self));
	{
		no strict 'refs';
		foreach my $class (@$no) {
			my $hasMethod = defined &{ ${"${class}::"}{$notification}};
			next unless $hasMethod;
			my $method = ${"${class}::"}{$notification};
			IF::Log::debug("++++++++++>>>>> Sending $notification to parent class $class of $self");
			$method->($self, $object, @arguments);
		}
	}
}

1;