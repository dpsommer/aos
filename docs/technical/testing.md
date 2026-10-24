# Testing

Tests are written using the [GUT (Godot Unit Testing)](https://github.com/bitwes/Gut) addon.

## Key practices

**Unit tests:**

- Must run quickly
- Success or failure of a test must be irrelevant for the success of another. No state should be maintained in the test suite
- Tests must be isolated from external dependencies
- Tests should check one single, specific aspect of a function, class, or module
- Avoid "A equals A" tests that simply check code values against identical test values
- Avoid fragile testing patterns, such as testing for specific constant values. Most of the time, updating a constant should not cause test failures

**Integration tests:**

- Should test a single integration, mocking or stubbing any other dependent components
- Should be used sparingly to test critical interactions between components or third-party dependencies
- Should mirror the real-world integration as closely as possible
- Should setup and teardown required state within the suite context
