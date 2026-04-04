**When talking about a side project, people usually share success stories.**

**Tools are up and running, data is ingested, logics are applied, and numbers are displayed.**

**That's cool.**

**But from my experience, you can learn even more from failures.**

**This might be weird advice, but trust me, try to break things.**

**Inject a bad record in your pipeline, scale up the data volume, or kill a worker.**

**Then there is a new set of problems that occur, and when you solve them, you will learn tons of other things, things that actually matter in real-life projects:**

1. **When the failures happen, will you know about it?**

- **You learn about observability: logging, monitoring, alerting.**

2. **What happens when the pipeline fails?**

- **You learn about fault-tolerance: can be the pipeline self-heal, is there any corrupt data when retry happens (idempotency). Can I backfill the data?**

3. **When the volume data increases, how do you deal with it?**

- **You learn about resource planning: does the solution support horizontal scaling, and how many resources should I add to ensure the data latency requirement.**

4. **When bad records appear, what will you do?**

- **You learn about data quality.**

---
**Just break things, in any creative way you can imagine, and don't forget to solve them**

https://vutr.substack.com/
---
