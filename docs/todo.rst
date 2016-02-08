=========
TODO List
=========

 * Add current working directory option to tasks.

 * Add implicit dependencies.
 
   1. Create explicit subgraph from the build state. ✓
   2. Create graph from list of rules. ✓
   3. Diff these two graphs to discover changes. ✓
   4. Sync with the build state depending on changes. ✓
   5. Add implicit dependencies to the build state after a task executes. ✓
   6. Publish dependencies if Brilliant Build is running under Brilliant Build. ✓
   7. Send list of changed inputs to task.
   8. Define protocol for sending input/output information.

 * Refactor and generalize graph traversal.
 
   1. Allow different graph traversal strategies (i.e., random, DFS, and BFS).

 * Generalize reporting of the build status.
 
   1. Should be able to output build status to a web page.
