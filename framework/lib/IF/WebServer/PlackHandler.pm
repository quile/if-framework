package IF::WebServer::PlackHandler;
use parent 'IF::WebServer::Handler';

use common::sense;

use IF::WebServer::Handler;
use IF::Request::Plack;

use Plack::Request;
use Plack::Response;
use Try::Tiny;

sub plackResponseFromResponse {
    my ($className, $response, $context) = @_;

    my $status = "200";
    my $headers = {};

    $className->didRenderInContext($context);

    my $r = $context->request();
    my $contentType = $response->contentType() || $context->contentType();

    if ($contentType) {
        $headers->{'Content-type'} = $contentType;
    }

    if ($context && $context->responseCode()) {
        $status = $context->responseCode();
    }

    my $isCached = 0;
    if ($context && $context->cacheControlMaxAge()) {
        my $cacheControl = "max-age=".$context->cacheControlMaxAge();
        $headers->{'Cache-Control'} = $cacheControl;
        $isCached = 1;
        # # never set cookies on pages that will be cached remotely
        # my $headers = $r->err_headers_out();
        # $headers->unset("Set-Cookie");
    } else {
        $headers->{'Cache-Control'} = "no-store";
    }

    unless ( $context->contentType() ) {
        $headers->{'Cache-Type'} = "text/html; charset=utf-8";
    }

    foreach my $header ( keys %{$context->request()->headers_out()} ) {
        next if ($isCached && $header eq 'Set-Cookie');
        $headers->{$header} = $context->request->headerValueForKey($header);
    }

    return Plack::Response->new(
        $status,
        $headers,
        $response->content(),
    );
}


sub transHandler {
    my ($className, $applicationName, $env) = @_;
    IF::Log::debug("=====================> Transhandler invoked");

    my $r = IF::Request::Plack->new(Plack::Request->new($env));
    $r->setApplicationName($applicationName);

    my $app = IF::Application->applicationInstanceWithName($applicationName);
    return undef unless IF::Log::assert($app, "Retrieved app instance for request");

    my $url = $r->uri();
    foreach my $module (@{$app->modules()}) {
        IF::Log::debug("Passing $url to module $module");

        # TODO implement caching here

        my ($rewrittenUrl, $rewrittenArgs) = $module->urlFromIncomingUrl($url);
        if ($rewrittenUrl ne $url) {
            IF::Log::debug("Rewriting as $rewrittenUrl ($rewrittenArgs) -> redirecting");
            $env->{"if.rewritten-url"}  = $rewrittenUrl;
            $env->{"QUERY_STRING"} = $rewrittenArgs;
            #$env->{"if.rewritten-args"} = $rewrittenArgs;
            #$r->uri($rewrittenUrl);
            #$r->args($rewrittenArgs) if $rewrittenArgs;
            # in mod_perl2 this prevents apache from running the
            # MapToStorage phase and saves a bunch of cycles.
            #$r->filename("TransHandler-N/A");
            #return OK;
            return
        }
    }

    # Small optimization ... if we know this url is going to be
    # handled by the big IF handler, we can give it a bogus
    # filename and avoid the map to storage grind
    #my $defaultPrefix = $r->dir_config('IFDefaultPrefix');
    #if ($url =~ /^$defaultPrefix/) {
    #    $r->filename("TransHandler-N/A");
    #    return OK;
    #}

    IF::Log::debug("No need to rewrite incoming URL");
    return; # DECLINED;
}



sub handler {
    my ($className, $applicationName, $env) = @_;
    my $context;
    my ($ERROR_CODE, $ERROR_MSG);

    # rewrite incoming URLs and munge the query string.
    $className->transHandler($applicationName, $env);

    my $req = IF::Request::Plack->new(Plack::Request->new($env));
    $req->setApplicationName($applicationName);

    my $res;

    IF::Log::setLogMask(0xffff);
    IF::Log::debug("=====================> Main handler invoked");

    #try {
        # generate a context for this request
        $context = $className->contextForRequest($req);
        unless ($context) {
            $ERROR_MSG = "Malformed URL: Failed to instantiate a context for request ".$req->uri();
            #$ERROR_CODE = NOT_FOUND;
            return;
        }

        # figure out what app and instance this is
        my $application = $context->application();
        unless ($application) {
            $ERROR_MSG = "No application object found for request ".$req->uri();
            #$ERROR_CODE = NOT_FOUND;
            return;
        }

        # Initialise the logging subsystem for this transaction
        $className->startLoggingTransactionInContext($context);

        # Set the language for this transaction so the I18N methods
        # use the right strings.
        IF::I18N::setLanguage($context->language());

        # figure out which component we're going to be running with
        my $component = $className->targetComponentForContext($context);
        unless ($component) {
            $ERROR_MSG = "No component object found for request ".$req->uri();
            #$ERROR_CODE = NOT_FOUND;
            return;
        }
        IF::Log::error("$$ - ".$context->urlWithQueryString());

        my $response;

        # just before append to response begins, push the CURRENT request's
        # sid into the query dictionary in case any component (like AsynchronousComponent)
        # decides to fish around in there to build urls
        $context->queryDictionary()->{$context->application()->sessionIdKey()} = $context->session()->externalId();

        $className->allowComponentToTakeValuesFromRequest($component, $context);

        my $actionResult = $className->actionResultFromComponentInContext($component, $context);

        # if we have a result from the action, set the component and the response
        # to be the appropriate objects
        if ($actionResult) {
            if (UNIVERSAL::isa($actionResult, "IF::Component")) {
                IF::Log::debug("Action returned a component $actionResult");
                $component = $actionResult;
                my $componentName = $component->componentNameRelativeToSiteClassifier();
                my $templateName = IF::Component::__templateNameFromComponentName($componentName);
                $response = IF::Response->new();
                my $template = $context->siteClassifier()->bestTemplateForPathAndContext($templateName, $context);
                $response->setTemplate($template);
            } elsif (UNIVERSAL::isa($actionResult, "IF::Response")) {
                # action returned a response; we have to assume it's fully populated and return it
                $response = $actionResult;
            } else {
                return $className->redirectBrowserToAddressInContext($actionResult, $context);
            }
        } else {
            $response = $className->responseForComponentInContext($component, $context);
        }

        # now we have $component and $response, no matter what the results of
        # the action were.
        if ($actionResult != $response) {
            my $responseResult = $className->allowComponentToAppendToResponseInContext($component, $response, $context);
            if ($responseResult) {
                return $className->redirectBrowserToAddressInContext($responseResult, $context);
            }
        }

        # This sends the generated response back to the client:
        # $className->returnResponseInContext($response, $context);

        $res = $className->plackResponseFromResponse($response, $context);

        #if ($logMask) {
            IF::Log::endLoggingTransaction();
        #    IF::Log::dumpLogForRequestUsingLogMask($r, $logMask);
        #}
    #} catch {

        # TODO:kd - report error, populate response

        # if ($ERROR_CODE) {
        #   IF::Log::debug($ERROR_MSG);
        #   return $ERROR_CODE;
        # }
        # if ($_) {
        #   if ($TRACE) {
        #       generateServerErrorPageForErrorInContextWithRequest($TRACE, $context, $r);
        #   } else {
        #       generateServerErrorPageForErrorInContextWithRequest($@, $context, $r);
        #   }
        #   IF::Log::clearMessageBuffer();
        # } else {
        #   return OK;
        # }
    #};

    $res->finalize();
}

1;