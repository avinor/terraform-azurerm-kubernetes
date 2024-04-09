
.PHONY: test
test:
	terraform test -no-color -verbose > tests/_actual.txt
	diff tests/_actual.txt tests/_expected.txt

.PHONY: test-update
test-update:
	terraform test -no-color -verbose > tests/_expected.txt