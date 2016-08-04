# Feedback

## Extension Mechanism

- execute only extensions or single extension or single extension file conveniently
- relative path should be possible
- want to add my tests to validator -> zip and ship
- no need to package, multiple clones with path configuration
- separate configuration values from extension path config
- there should be a default extension folder (explicit or implicit, without params)
- params for extensions make sense
- params as file path or declared value

## Config

- support multiple credentials (for validator in general)

## API

- even more, semantic helpers? e.g. port created and accessible

### provides, consumes

- namespacing per spec
- be careful, when it grows, it's a nightmare, would not use it

### OpenStack CLI Wrapper
- user expects to handle errors by himself
- user does not expect to handle errors by himself -> we need to support both, we actually do, but also provide exit code
- don't use JSON magic, user can define that by himself and knows what his command returns (no surprises).
  Also dangerous, we might not cover all commands, have to follow API.
- use multiple params or single arguments param? multiple does not work with current 'magic'

### Fog

- I don't need this
- yeah, I would use this

### CPI

- unclear, not needed

## Resource Handling

- API methods should handle resource tracking and clean up automatically
- implementors are clever enough to clean up by themselves

## Documentation

- prerequisite: openstack cli 2.6?

- regular validator documentation
  - project name in `validator.template.yml`
  - refer in `validator.template.yml` to prerequisites

## Error Handling

- if extension mechanism fails:
    - we see log file location twice
    - no clear error output that tests failed, only log file hint

## BOSH

- BOSH should create all IaaS resources as needed
- we would like to use `bosh deploy` in a test, bosh helper/API?

## Misc

- too much API, more than needed? Implementors want to use the same stuff as we do

## Validator in General

- why should I provide network, floating ip? the tests should create everything and cleanup
- should do BOSH deployment with dummy release (sth. like mini BATs)
- remove CF in Validator name, wrong assumptions