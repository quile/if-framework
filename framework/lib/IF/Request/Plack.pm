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
    $self->{_cookies} = { %{$r->cookies} };
    $self->{_cookiesOut} = {};
    return $self;
}

sub dropCookie {
    my $self = shift;
    my $options = { @_ };

    return unless IF::Log::assert($options->{'-name'}, "Can't set cookie without a name");

    my $expires = $options->{'-expires'};

    # for now, we only support either-or... session (meaning it will expire
    # at the end of this browser session) or 1 year.
    if ($expires eq "+12M") {
        $expires = time + 365 * 24 * 60 * 60;
        $self->{_cookiesOut}->{ $options->{'-name'} } = {
            value => $options->{'-value'},
            expires => $expires,
            path => $options->{'-path'},
            domain => $options->{'-domain'},
        };
    } else {
        $self->{_cookiesOut}->{ $options->{'-name'} } = $options->{'-value'};
    }
}

sub uri {
    my ($self) = @_;
    #return $self->{r}->uri();
    # what we call "uri", Plack (correctly) calls path_info:
    return $self->{r}->env->{'if.rewritten-url'} || $self->{r}->path_info();
}

sub cookieValueForKey {
    my ($self, $key) = @_;
    return $self->{_cookiesOut}->{$key}->{value} || $self->{_cookies}->{$key};
}

sub outgoingCookies {
    my ($self) = @_;
    return $self->{_cookiesOut};
}

sub upload {
    my ($self, $key) = @_;
    return $self->{r}->upload($key);
}

sub param {
    my ($self, $key) = @_;
    if (wantarray) {
        if ($key) {
            return $self->{r}->parameters->get_all($key);
        }
        return keys %{$self->{r}->parameters};
    }
    return $self->{r}->parameters->get_one($key);
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
    return $self->{r}->env()->{'if.rewritten-args'} || $self->{r}->env()->{QUERY_STRING};
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
