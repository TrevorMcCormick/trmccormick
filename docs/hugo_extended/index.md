# Buildspec for Hugo Extended on Amazon Linux 2


Are you frustrated that your Hugo website builds are not reflecting your local changes? If you're using `scss` files to manage your website styling, and the changes you make locally are not showing up on web server, then you might be facing challenges installing Hugo Extended.

Here are some common errors you might see in AWS CloudWatch:

```bash 
hugo: /lib64/libm.so.6: version 'GLIBC_2.29' not found (required by hugo)
hugo: /lib64/libstdc++.so.6: version 'GLIBCXX_3.4.26' not found (required by hugo)
```
```go
tpl/internal/go_templates/texttemplate/helper.go:11:2: package io/fs is not in GOROOT (/root/.goenv/versions/1.14.12/src/io/fs)
```

To resolve these errors, you need to do three things within your buildspec:
1. Download a specific version of `Go` that will work with Hugo Extended
2. Adjust your web server environment variables to use a specific version of `Go`
3. Using `Go` to install Hugo Extended

Here is the buildspec I'm using for my site, so feel free to copy the `install` commands for your own use.
```yaml
version: 0.2

phases:
  install:
    commands:
      - echo Entered the install phase...
      - wget https://golang.org/dl/go1.16.7.linux-amd64.tar.gz #installs Go 1.16.7
      - tar -xzf go1.16.7.linux-amd64.tar.gz #extracts gzipped archive file
      - mv go /usr/local  #moves go to /usr/local
      - export GOROOT=/usr/local/go #adds go to env variable
      - export PATH=$GOPATH/bin:$GOROOT/bin:$PATH  #adds go to path
      - go version #print version of go to console
      - yum install asciidoctor -y #my hugo template needs asciidoctor
      - mkdir $HOME/src #make new src dir
      - cd $HOME/src #go to src dir
      - git clone https://github.com/gohugoio/hugo.git #clone hugo
      - cd hugo #go to hugo dir
      - go install --tags extended #use go to install extended hugo
    finally:
      - echo Installation done
  build:
    commands:
      - echo Building...
      - echo Build started on `date`
      - cd $CODEBUILD_SRC_DIR
      - hugo --quiet
      - aws s3 sync --delete docs/ s3://trmccormick.com
      - aws cloudfront create-invalidation --distribution-id **** --paths '/*'
    finally:
      - echo Build finished
artifacts:
  files:
    - '**/*'
  base-directory: $CODEBUILD_SRC_DIR/docs
  discard-paths: no
  ```
