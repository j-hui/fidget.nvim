[private]
default: help

# Show just recipes
help:
    just -f "{{justfile()}}" -l

# Run tests
test:
    nvim --clean --headless -u tests/minimal_init.lua -c "PlenaryBustedDirectory tests/ { minimal_init = 'tests/minimal_init.lua' }"

# Render api documentation
build-api-docs:
    ./scripts/build-api-docs.sh

# Render options documentation
build-options-docs:
    ./scripts/build-options-docs.sh
