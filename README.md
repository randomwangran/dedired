# dedired


[Protesilaos/denote: is an efficient file-naming scheme](https://github.com/protesilaos/denote). It was
designed to take notes. I found the code itself relatively easy to
understand, so I "borrow" some of the snippets to create a new package.

It is called [dedired/dedired.el](https://github.com/randomwangran/dedired/blob/main/dedired.el). The motivation for this package is
to reuse the file-naming scheme but for the folder instead. This is because I
often find myself creating a new folder when I generate 3D models.
A single big directory is not good, since there will be a different file
formats.

Once you have `dedired.el` install,

```elisp
(setq denote-directory "/YOUR/PATH/")
```

By calling it:

`M-x dedired`

You will create a directory under `/YOUR/PATH/`:

```bash
DATE
DATE--TITLE
DATE__KEYWORDS
```

Happy create folders!
