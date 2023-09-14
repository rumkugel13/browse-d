# Drowsey: A Web Browser in D

Based on [the browser book](https://browser.engineering/)

## Progress

- [x] Part 1: Drawing Graphics
  - [X] Downloading Web Pages
    - [X] URL Parsing
    - [X] Connecting to Host
      - [ ] Encryption
    - [X] Send HTTP Request
    - [X] Receive and Split HTTP Response
    - [X] Print Text
    - [ ] Exercises (Optional)
      - [ ] Alternate Encodings
      - [ ] HTTP/1.1
      - [ ] File URLs
      - [ ] data
      - [ ] Body tag
      - [ ] Entities
      - [ ] view-source
      - [ ] Compression
      - [ ] Redirects
      - [ ] Caching
  - [x] Drawing to the Screen
    - [x] Window Creating
    - [x] Text Layout and Drawing
    - [x] Listening to Key Events
    - [x] Scrolling the content in the window
    - [ ] Exercises (Optional)
      - [x] Line breaks
      - [x] Mouse wheel
      - [ ] Emoji
      - [ ] Resizing
      - [ ] Zoom
  - [x] Formatting Text
    - [x] Text Layout word by word
    - [x] Split lines at words
    - [x] Text can be bold and italic
    - [x] Text in different sizes can be mixed
    - [ ] Exercises (Optional)
      - [ ] Centered Text
      - [ ] Superscripts
      - [ ] Soft hyphens
      - [ ] Small caps
      - [ ] Preformatted text
- [ ] Part 2: Viewing Documents
  - [x] Constructing a Document Tree
    - [x] HTML parser
    - [x] Handling attributes
    - [x] Some fixes for malformed HTML
    - [x] Recursive layout algorithm for tree
    - [ ] Exercises (Optional)
      - [ ] Comments
      - [ ] Paragraphs
      - [ ] Scripts
      - [ ] Quoted attributes
      - [ ] Syntax highlighting
  - [ ] Laying Out Pages
  - [ ] Applying Author Styles
  - [ ] Handling Buttons and Links
- [ ] Part 3: Running Applications
  - [ ] Sending Information to Servers
  - [ ] Running Interactive Scripts
  - [ ] Keeping Data Private
- [ ] Part 4: Modern Browsers
  - [ ] Adding Visual Effects
  - [ ] Scheduling Tasks and Threads
  - [ ] Animating and Compositing
  - [ ] Making Content Accessible
  - [ ] Supporting Embedded Content
  - [ ] Reusing Previous Computation

## Notes

- Part 1
  - Couldn't get [SSL](https://browser.engineering/http.html#encrypted-connections) to work, due to linker errors