# Questions and answers

Short answers. For error messages and what to do about them, read [Fixing problems](Fixing%20problems.md).

**Is anything really printed?** Not yet. Printing goes through `IPrintDispatcher`, which is simulated. A real printer needs a real dispatcher ([issue #5](https://github.com/Hikki-dev/pull_printing_app/issues/5)).

**Can I send my own file?** Not yet. The demo makes sample documents. See [issue #4](https://github.com/Hikki-dev/pull_printing_app/issues/4).

**When do page limits start again?** On the 1st of every month, UTC.

**What is the difference between the live demo and the full stack?** The live demo on Vercel runs entirely in your browser on sample data. The full stack runs the real server, with its sign-in, printers and limits. See [Hosting the demo](06-demo-hosting.md).

**Do I lose my data if the server restarts?** Yes, for now. People, printers, limits and documents are held in memory until a database backs `IPrintStore` ([issue #3](https://github.com/Hikki-dev/pull_printing_app/issues/3)). Sign-in sessions survive a restart only if `Auth__SigningKey` is set.

**Who can see my documents?** Only you. The server ignores any document that is not yours and waiting.

**Is this a finished product?** No. It is a working demo and a prototype of the idea. See the Limits in the [README](../README.md#limits).
