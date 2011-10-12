package IF::Request::Plack;

use common::sense;
use base qw( IF::Request );

sub new {
    my ($className, $r) = @_;
    my $self = bless { r => $r }, $className;

    my @headerFieldNames = $r->headers()->header_field_names();
    my $headers = {};
    foreach my $name (@headerFieldNames) {
        $headers->{$name} = $r->header($name);
    }
    $self->{_headers_in}  = $headers;
    $self->{_headers_out} = {};
    return $self;
}

#sub dropCookie {
    # my $self = shift;
    # my $cookie = Apache2::Cookie->new($self, @_);
    # unless ($cookie) {
    #     IF::Log::error("Failed to create cookie ".join(", ", @_));
    #         return;
    #     }
    # $cookie->bake($self);
    # return $cookie;
#}

sub uri {
    my ($self) = @_;
    #return $self->{r}->uri();
    # what we call "uri", Plack (correctly) calls path_info:
    return $self->{r}->path_info();
}

sub cookieValueForKey {
    my ($self, $key) = @_;
    my $c = $self->{r}->cookies()->{$key};
    return $c;
}

sub upload {
    my ($self, $key) = @_;
    return $self->{r}->upload($key);
}

sub param {
    my ($self) = @_;
    return $self->{r}->param(@_);
}

sub headers_in {
    my ($self) = @_;
    return $self->{_headers_in};
}

sub headers_out {
    my ($self) = @_;
    return $self->{_headers_out};
}

sub args {
    my ($self) = @_;
    return $self->{r}->env()->{QUERY_STRING};
}

sub pnotes {
    my ($self, $key, $value) = @_;
    if ($key) {
        $self->{r}->env()->{$key} = $value;
    } else {
        return $self->{r}->env();
    }
}

1;
