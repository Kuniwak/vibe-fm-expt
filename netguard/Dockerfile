# Holds the network namespace that the workspace container joins and applies
# egress rules to it. The workspace container itself gets no NET_ADMIN and
# never sees these rules or this script.
FROM alpine:3.22@sha256:49340b346798875b5592e5d420241f2f9cfba5f47e62ebb1446a1b34734e898f
RUN apk add --no-cache iptables ip6tables ipset bind-tools
COPY apply.sh /apply.sh
ENTRYPOINT ["/bin/sh", "/apply.sh"]
