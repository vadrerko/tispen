# tispen 🚀

**tispen** is a lightweight, zero-overhead, keyboard-driven Literate Programming environment, text editor, and interactive SQL client built for the terminal, combining the console editor **tcled** with an embedded evaluation engine.

---

## 🔍 What's in a Name?

**tispen** stands for:
*   **T**cl **I**nteractive **S**ql & **P**erl **E**nvironmental **N**otebook
*   **T**cl **I**nteractive **S**ql **Perl** **E**ngine

### 🇳🇴 The Nordic Easter Egg
If you run `tispen` through Google Translate, it might tell you that in Norwegian, it translates to *"the female dog"*. We consider this a feature denoting dogged loyalty, speed, and bite when processing queries.

---

## 💡 Philosophy & Features

*   **Plain Text First:** Uses standard `.sess.in` session files that are fully Git-friendly.
*   **Persistent State:** Perl holds live database connections (`$::dbh`) and variable pools in memory.
*   **Polyglot Blocks:** Mix raw Perl (`=perl`) and SQL statements (`=sql`) in a single session file with template interpolation.
*   **Flexible Layouts:** Renders query results into ASCII tables, Jira markup, or raw dumps.

---

## ⏱️ Quick Start

```bash
# Install dependencies (Ubuntu/Debian example)
sudo apt update && sudo apt install libtcl-perl libtext-template-perl libdbi-perl libdbd-sqlite3-perl

# Launch a session
perl tispen.pl my_analytics.sess.in
```

Replace the `libdbd-sqlite3-perl` with your SQL driver.

Press Ctrl+K on empty line and follow example.

---

## Example session

```
{{{ # here perl code executed each time on execution for 'untemplate' phase - but
# if $spen::untemplatep flag is ON
''
}}}\
=ie

# for Perl execution - Ctrl+K
use DBI; $::dbh = DBI->connect("dbi:SQLite:dbname=try-1.sqlite","","");
DBI::db=HASH(0x3000c8a8c8)
Notice that you can call anything for DB connection: $::dbh = my_connect_function(...) from your own library

# config:
$spen::untemplatep = 0
$spen::anchorp = 0
$spen::width = 123;

# for SQL execution - Ctrl+N
select 1 as n
┌─┐
│n│
╞═╡
│1│
└─┘

# for Perl execution - Ctrl+K - you can also eval tcl and inspect its variables
$int->Eval('expr 2+3')

=cut

select "a" a,"b" as b union all select 'Peter','{{{"a"x1000}}}'
---select "a" a,"b" as b union all select 'Peter','aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
┌─┬────────────────────────────────────────────────────────────────────────────────┐
│a│                                                                               b│
╞═╪════════════════════════════════════════════════════════════════════════════════╡
│a│                                                                               b│
│P│aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa│
│e│aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa│
│t│aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa│
│e│aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa│
│r│aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa│
│ │aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa│
│ │aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa│
│ │aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa│
│ │aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa│
│ │aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa│
│ │aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa│
│ │aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa│
│ │                                        aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa│
└─┴────────────────────────────────────────────────────────────────────────────────┘

=Sql name/f=+
WITH RECURSIVE generate_series(value) AS (
    SELECT 1
    UNION ALL
    SELECT value + 1 FROM generate_series WHERE value < 10
)
SELECT value FROM generate_series
=Cut
{code:sql|borderColor=#00DD00}
WITH RECURSIVE generate_series(value) AS (
    SELECT 1
    UNION ALL
    SELECT value + 1 FROM generate_series WHERE value < 10
)
SELECT value FROM generate_series
{code}
┌──┐
│va│
│lu│
╞══╡
│ 1│
│ 2│
│ 3│
│ 4│
│ 5│
│ 6│
│ 7│
│ 8│
│ 9│
│10│
└──┘

=perl
use Data::Dumper; Dumper \%::r
=Cut
$VAR1 = {
          't_a_b' => 1,
          'name' => [
                      [
                        1
                      ],
                      [
                        2
                      ],
                      [
                        3
                      ],
                      [
                        4
                      ],
                      [
                        5
                      ],
                      [
                        6
                      ],
                      [
                        7
                      ],
                      [
                        8
                      ],
                      [
                        9
                      ],
                      [
                        10
                      ]
                    ],
          't_n' => 1
        };
```


---

## Memory leak WARNING

The tool save results into the `%::r` and `%::res` hashes, so  empty these hashes from time to time!

## See also

- https://github.com/vadrerko/vispen
- https://github.com/slebetman/tcled

---

## 📄 License
MIT / Same as Tcl and Perl.
