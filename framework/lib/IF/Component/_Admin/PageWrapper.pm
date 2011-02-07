package IF::Component::_Admin::PageWrapper;

use strict;
use base qw(
    IF::Component::_Admin
);

sub Bindings {
    return {
        user_can_view_page => {
            type => "BOOLEAN",
            value => q(context.session.userCanViewAdminPages),
        },
        content => {
            type => "CONTENT",
        },
    };
}

1;