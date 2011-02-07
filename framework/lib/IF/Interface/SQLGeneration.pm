package IF::Interface::SQLGeneration;

# This is the beginnings of an interface that can be
# implemented by objects that generate SQL... it's
# just the germ of an idea for now but will
# be fleshed out into more detail in the future.

use strict;

sub translateConditionIntoSQLExpressionForModel {
	my ($self, $sqlExpression, $model) = @_;
	IF::Log::warning("$self - unimplemented method: translateConditionIntoSQLExpressionForModel");
}

sub translateIntoHavingSQLExpressionForModel {
	my ($self, $sqlExpression, $model) = @_;
	IF::Log::warning("$self - unimplemented method: translateIntoHavingSQLExpressionForModel");	
}

1;