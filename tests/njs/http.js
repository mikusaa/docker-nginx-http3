// @see https://nginx.org/en/docs/njs/
// @see https://nginx.org/en/docs/njs/reference.html
function hello(r) {
    r.headersOut['x-njs'] = '1';
    r.return(200, `Hello world from njs v${njs.version}\n`);
}

function stream(r) {
    r.status = 200;
    r.headersOut['Content-Type'] = 'text/plain';
    r.sendHeader();
    r.send('first chunk\n');
    r.send('second chunk\n');
    r.finish();
}

export default {hello, stream};
