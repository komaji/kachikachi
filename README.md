# Kachikachi

Kachikachi is counter of deleted lines on GitHub pull request.

```sh
$ bundle exec kachikachi count --repo=test --milestones=1.0.0

path/to/file: deleted 1 lines
path/to/file: deleted 1 lines
path/to/file: deleted 6 lines
path/to/file: deleted 150 lines
path/to/file: deleted 1 lines
👋👋👋 total 159 lines 👋👋👋
```

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'kachikachi'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install kachikachi

## Usage

Set `KACHIKACHI_GITHUB_TOKEN` to your Github personal access token which requirs only repo scope.

```
$ export KACHIKACHI_GITHUB_TOKEN={YOUR_TOKEN}
```

Count command requires arguments `--repo` and `--milestones` or `pull-request-numbers`.

```sh
$ bundle exec kachikachi count --repo={REPO} --milestones={1.0.0 2.0.0} or pull-request-numbers={1 2 3}
```

Example output.


### Options

```sh
Options:
  [--endpoint=ENDPOINT]
                                                     # Default: https://api.github.com/
  [--token=TOKEN]
  --repo=REPO
  [--file-regexp=FILE-REGEXP]
  [--milestones=one two three]
  [--pull-request-numbers=one two three]
  [--state=STATE]
                                                     # Default: closed
  [--ignore-white-space], [--no-ignore-white-space]
                                                     # Default: true
  [--ignore-comment-regexp=IGNORE-COMMENT-REGEXP]
  [--base-branch=BASE-BRANCH]
  [--user=USER]
```

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/komaji/kachikachi. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the Kachikachi project’s codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/komaji/kachikachi/blob/master/CODE_OF_CONDUCT.md).
