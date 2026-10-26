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

---

## Memory leak WARNING

The tool save results into %::r and %::res, so  empty these hashes from tim eto time!

## See also

- https://github.com/vadrerko/vispen
- https://github.com/slebetman/tcled

---

## 📄 License
MIT / Same as Tcl and Perl.
