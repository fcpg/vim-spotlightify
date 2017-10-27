```
  A\_               _                      _      (o)
 /`Y    \  /o._ ___(_`._  __|_|o _ |__|_o_|_     /   
 \       \/ || | | ,_)|_)(_)|_||(_|| ||_| |\/    \   
 ^                    |          _|        /     ^   
```

Spotlightify highlights your search results while you are navigating through
them (with `n/N` and family), and automatically turn the highlighting off when
you are done.

Occurrence under cursor is highlighted differently ("spotlit") for easier
navigation.

By default, `c<Tab>` is mapped to a "search & replace" on the current word,
repeatable (with `.`) on other occurrences of that word. All instances are
highlighted accordingly during the operation.

[![asciicast](https://asciinema.org/a/dcFbyEBaHTUNUCX3ZEmYoz4mh.png)](https://asciinema.org/a/dcFbyEBaHTUNUCX3ZEmYoz4mh)

Requirements
-------------
This plugin requires `execute()` function and `OptionSet` event 
(Vim8 or late 7.4 patches).

Installation
-------------
Use your favorite method:
*  [Pathogen][1] - git clone https://github.com/fcpg/vim-spotlightify ~/.vim/bundle/vim-spotlightify
*  [NeoBundle][2] - NeoBundle 'fcpg/vim-spotlightify'
*  [Vundle][3] - Plugin 'fcpg/vim-spotlightify'
*  manual - copy all files into your ~/.vim directory

Acknowledgments
----------------
Originally a fork from [@romainl](https://github.com/romainl) `vim-cool`.

Many thanks to [@igemnace](https://github.com/igemnace) on #vim for testing.

License
--------
[Attribution-ShareAlike 4.0 Int.](https://creativecommons.org/licenses/by-sa/4.0/)

[1]: https://github.com/tpope/vim-pathogen
[2]: https://github.com/Shougo/neobundle.vim
[3]: https://github.com/gmarik/vundle
