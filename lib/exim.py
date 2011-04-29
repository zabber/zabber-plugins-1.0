#!/usr/bin/python

import os, re

def parse_log(fname, trusted):
    (s_local, s_relay, s_other, s_error,d_local,d_relay,d_other,d_defer,d_failure,d_unknown) = (0,0,0,0,0,0,0,0,0,0,)
    id_defer={}
    id_failure={}
    submit = re.compile("^[^ ]+ [^ ]+ [^ ]+ <= ([^ ]+) (.*)")
    submit_rest = re.compile("H=([^ (]*).* \[([^]]+)\] .*")
    delivery = re.compile("^[^ ]+ [^ ]+ [^ ]+ => .* T=[^ ]* ?(.*)")
    delivery_local = re.compile("^$")
    delivery_remote = re.compile("H=([^ ]*) \[([^]]+)] ?.*")
    delivery_defer = re.compile("^[^ ]+ [^ ]+ ([^ ]+) == .*")
    delivery_failure = re.compile("^[^ ]+ [^ ]+ ([^ ]+) \*\* .*")
    f = open(fname, 'r')
    for l in f.readlines():
        s = submit.match(l)
        if s:
            (address, rest) = s.groups()
            r = submit_rest.match(rest)
            if r:
                (hostname, ip) = r.groups()
                if ip == "127.0.0.1":
                    s_local+=1
                elif trusted.get(hostname,False) or trusted.get(ip,False):
                    s_relay+=1
                else:
                    s_other+=1
            elif address == "<>":
                s_error+=1
            else:
                s_local+=1
        else:
            d = delivery.match(l)
            if d:
                (rest,) = d.groups()
                if delivery_local.match(rest):
                    d_local+=1
                else:
                    rem = delivery_remote.match(rest)
                    if rem:
                        (hostname, ip) = rem.groups()
                        if trusted.get(hostname,False) or trusted.get(ip,False):
                            d_relay+=1
                        else:
                            d_other+=1
                    else:
                        print rest
                        d_unknown+=1
            else:
                d = delivery_defer.match(l)
                if d:
                    (msgid,)=d.groups()
                    id_defer[msgid]=True
                else:
                    d = delivery_failure.match(l)
                    if d:
                        (msgid,)=d.groups()
                        id_failure[msgid]=True
    f.close()
    return {
        'submit.from.local': s_local,
        'submit.from.relay': s_relay,
        'submit.from.other': s_other,
        'submit.from.error': s_error,
        'delivery.to.local': d_local,
        'delivery.to.relay': d_relay,
        'delivery.to.other': d_other,
        'delivery.to.unknown': d_unknown,
        'delivery.error.defer': len(id_defer),
        'delivery.error.failure': len(id_failure),
    }

def collect(f):
    ret = parse_log('/var/log/exim4/mainlog',{})
    f.write("CHECK OK\n")
    for k in ret.keys():
        f.write("%s %s\n" % (k, ret[k]))

if __name__ == '__main__':
    import sys
    collect(sys.stdout)
