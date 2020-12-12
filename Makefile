SHELL = /bin/bash

NAME ?= tvial/docker-mailserver:testing

VCS_REF := $(shell git rev-parse --short HEAD)
VCS_VERSION := $(shell git describe --tags --contains --always)

all: build backup generate-accounts tests clean
no-build: backup generate-accounts tests clean
complete_test: lint build generate-accounts tests

build:
       docker build -t $(NAME) . \
               --build-arg VCS_REF=$(VCS_REF) \
               --build-arg VCS_VERSION=$(VCS_VERSION) \

backup:
# if backup directories exist, clean hasn't been called, therefore
# we shouldn't overwrite it. It still contains the original content.
	@ [[ ! -d config.bak ]] && cp -rp config config.bak
	@ [[ ! -d testconfig.bak ]] && cp -rp test/config testconfig.bak

generate-accounts:
	@ docker run --rm -e MAIL_USER=user1@localhost.localdomain -e MAIL_PASS=mypassword -t $(NAME) /bin/sh -c 'echo "$$MAIL_USER|$$(doveadm pw -s SHA512-CRYPT -u $$MAIL_USER -p $$MAIL_PASS)"' > test/config/postfix-accounts.cf
	@ docker run --rm -e MAIL_USER=user2@otherdomain.tld -e MAIL_PASS=mypassword -t $(NAME) /bin/sh -c 'echo "$$MAIL_USER|$$(doveadm pw -s SHA512-CRYPT -u $$MAIL_USER -p $$MAIL_PASS)"' >> test/config/postfix-accounts.cf
	@ echo "# this is a test comment, please don't delete me :'(" >> test/config/postfix-accounts.cf
	@ echo "           # this is also a test comment, :O" >> test/config/postfix-accounts.cf

tests:
	./test/bats/bin/bats test/*.bats

.PHONY: ALWAYS_RUN
test/%.bats: ALWAYS_RUN
	./test/bats/bin/bats $@

clean:
# remove running and stopped test containers
	-@ docker ps -a | grep -E "docker-mailserver:testing|ldap_for_mail" | cut -f 1-1 -d ' ' | xargs --no-run-if-empty docker rm -f
	-@ [[ -d config.bak ]] && { rm -rf config ; mv config.bak config ; } || :
	-@ [[ -d testconfig.bak ]] && { sudo rm -rf test/config ; mv testconfig.bak test/config ; } || :
	-@ sudo rm -rf test/onedir test/alias test/quota test/relay test/config/dovecot-lmtp/userdb test/config/key* test/config/opendkim/keys/domain.tld/ test/config/opendkim/keys/example.com/ test/config/opendkim/keys/localdomain2.com/ test/config/postfix-aliases.cf test/config/postfix-receive-access.cf test/config/postfix-receive-access.cfe test/config/dovecot-quotas.cf test/config/postfix-send-access.cf test/config/postfix-send-access.cfe test/config/relay-hosts/chksum test/config/relay-hosts/postfix-aliases.cf test/config/dhparams.pem test/config/dovecot-lmtp/dh.pem test/config/relay-hosts/dovecot-quotas.cf test/config/user-patches.sh test/alias/config/postfix-virtual.cf test/quota/config/dovecot-quotas.cf test/quota/config/postfix-accounts.cf test/relay/config/postfix-relaymap.cf test/relay/config/postfix-sasl-password.cf test/duplicate_configs/

lint: eclint hadolint shellcheck

hadolint:
	@ ./test/linting/lint.sh hadolint

shellcheck:
	@ ./test/linting/lint.sh shellcheck

eclint:
	@ ./test/linting/lint.sh eclint
