#!/bin/sh

# Alpine's /etc/profile resets PATH for login shells, which would otherwise
# drop tool locations added by the image ENV PATH directives.
case ":$PATH:" in
  *:/usr/local/go/bin:*) ;;
  *) PATH="/usr/local/go/bin:$PATH" ;;
esac

case ":$PATH:" in
  *:/usr/local/custom-bin:*) ;;
  *) PATH="/usr/local/custom-bin:$PATH" ;;
esac

export PATH
