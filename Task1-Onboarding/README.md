# DevOps Internship: Task 1 Onboarding Answers

**Name:** Rishi Panchal
**GitHub:** rishipanchal1775

---

## 1. Introduction

Hi everyone, I'm Rishi Panchal. I completed my BCA (Bachelor of Computer Applications) from The Maharaja Sayajirao University of Baroda in 2026.

**Background:** During my degree I taught myself the MERN stack (MongoDB, Express, React, Node.js) and built three full-stack projects. This gave me a good understanding of how web applications are built and how the different parts of a tech stack work together.

**Interests:** I enjoy problem-solving, self-directed learning, and working with systems rather than just writing code. I like figuring things out hands-on, I stay consistent once I commit to something, and I'm comfortable learning independently through practice and experimentation.

**Where I am now:** I'm moving into DevOps. I'm currently learning Linux, shell scripting, and Docker, with the goal of becoming a skilled DevOps Engineer.

**What I want to learn in this internship:**
- Git and GitHub workflows used by real teams (branches, pull requests, code reviews)
- Docker and containers, and then Kubernetes
- Linux and shell scripting for automation
- AWS, Jenkins, Terraform, etc tools
- Good engineering habits: documentation, safe handling of credentials, clear status updates, and asking for help well

**Preferred working hours:** [e.g., 10:00 AM to 6:00 PM IST, Monday to Friday]

I'm happy to connect with mentors, peers, and professionals in the DevOps space, and I welcome any feedback.

---

## 2. Contexer: what I understood

Contexer is an open-source tool that works with AI coding agents such as Claude Code, Cursor, Codex, and Gemini CLI. Its job is to be the "decision and enforcement layer" for them. AI agents often forget instructions when a session gets long, or lose them when you switch tools. Contexer stores the important engineering decisions in one place and gives them back to the agent when they are needed.

It works in four steps: **capture** decisions while you work, **review** them, **replay** the approved ones in later sessions, and **check** new changes against them.

### Decisions
A decision is an important choice or rule about how a project should be built. Examples are "we use PostgreSQL for the database" or "never commit directly to main". Contexer captures these as I work and stores them, with their history, so they don't stay buried in old chat sessions. In my own words, a decision is a settled answer the agent should follow instead of guessing again.

### Context
Context is the background information an AI agent needs to work properly in a project: the decisions, constraints, and conventions. Contexer does not dump everything into the agent. It injects only the relevant piece when the agent needs it, so the agent starts from the settled answer and does not waste time re-exploring. Context is the right information, delivered at the right moment.

### Review
Review is the human approval step. Contexer proposes decisions from what it captured, and the developer chooses which ones become trusted. Only approved decisions are used later. Edits keep a history rather than overwriting the old version. This keeps a human in control, so the AI can't quietly turn a wrong guess into a permanent rule.

### Guard
Guard is an optional safeguard that runs at commit time, as a git pre-commit hook. It compares the staged changes against approved decisions and flags any that violate one. By default it only warns (advisory). It can block a commit only when a developer has explicitly set up a machine-checkable rule for an approved decision. Guard turns a decision from advice into something enforced. It is opt-in and has to be installed in a repo deliberately.

**Questions for my mentor:** [add anything you are unsure about, or delete this line]

---

## 3. What I expect to learn in the two-phase Kubernetes assignment

I know Docker lets me package an application into a container. I expect Kubernetes to teach me how to run and manage many containers reliably, which is much closer to real production DevOps work. In the first phase I expect to learn the core building blocks: pods, deployments, services, and how to describe an application in YAML manifests. I also expect to learn how to deploy a small app and check its health using `kubectl`.

In the second phase I hope to go deeper into running applications more realistically. That includes scaling, rolling updates and rollbacks, configuration and secrets, networking, and troubleshooting a broken deployment using logs and events. I also want to connect this to my AWS fundamentals and understand how Kubernetes is run in the cloud.

By the end I want to be able to deploy an application on Kubernetes myself, explain each part in my own words, and debug common problems without just copying commands. I'm new to Kubernetes, so I expect to make mistakes. I'll document what goes wrong and how I fix it, and I'll ask my mentor for the exact structure of the two phases so I can focus on the right topics.

---

## 4. Machine and OS

| Item | Details |
|------|---------|
| Laptop / PC | [e.g., Dell Latitude 5530, 16 GB RAM] |
| Operating system | [e.g., Windows 11 with WSL2 Ubuntu 24.04] |
| Shell / terminal | [e.g., Ubuntu terminal in WSL2, bash] |
| Code editor | [e.g., VS Code] |

---

## 5. Installed tools and versions

| Tool | Version | Check command |
|------|---------|---------------|
| Git | version 2.53.0 | `git --version` |
| Python 3 | version 3.14.4 | `python3 --version` |
| pip | pip 25.1.1 from /usr/lib/python3/dist-packages/pip (python 3.14) | `pip --version` |
| Docker | Docker version 29.8.2, build 7fc2dff | `docker --version` |
| VS Code | 1.141.1 | `code --version` |
| Claude Code | 2.1.301 (Claude Code) | `claude --version` |

---

## 6. What I learned

- **Git and GitHub:** a branch is a separate line of work, a commit is a saved snapshot, and a pull request asks for review before merging. [Add anything you noticed yourself.]
- **Dependency isolation:** a virtual environment gives each project its own packages and versions, so projects don't conflict and my system Python stays clean. `requirements.txt` lets someone recreate the same environment.
- **Docker:** an image is a read-only template, a container is a running instance of it, and port mapping (`-p 8080:80`) connects a port on my machine to a port inside the container.
- **Linux:** I practised commands for files, processes, permissions, networking and logs. For example, `chmod 755` gives the owner read, write and execute, and everyone else read and execute.
- **Shell scripting:** I wrote a script that checks required tools and exits with a failure code if one is missing, so it can be used in automation.
- **Notion:** I learned to use checkboxes, properties, comments, and uploading evidence such as screenshots and links.
- **AI coding assistant:** prompts are my instructions, tools are the actions the assistant can take, permissions are the approvals I give before it runs risky actions, and project instructions (such as `CLAUDE.md`) tell it how my project works.
- **Communication:** a good blocker message says what I tried, the exact error, and what I need. A status update covers done, next, and blocked.

---

## 7. Problems encountered

### Problem 1: Learning how Notion works
**Problem:** I had not used Notion before, so I was not sure how to navigate the workspace, tick task items, add evidence like screenshots and links, and use comments to reach my mentor.

**How I solved it:** I explored the workspace step by step. I learned that checkboxes track progress, the `/` command inserts links, images and files, comments with `@mentor` notify the reviewer, and properties such as Status show where a task is. I also used the tracker to see how tasks are organised.

**Lesson:** Learning the team's tools early saves time later. I should explore a new tool with a small practice task before I need it for real work.

### Problem 2: Integrating Claude Code into DevOps tasks
**Problem:** I was not sure how to use Claude Code for DevOps work, such as writing shell scripts, Docker commands and Git steps, while still understanding what I was doing. I also had to learn how permissions work so the assistant would not run commands I didn't understand.

**How I solved it:** I started in a disposable folder rather than a real project. I read each proposed command before approving it, asked it to explain commands I didn't recognise, and ran and tested the results myself. I also learned that a project instructions file such as `CLAUDE.md` helps it follow my conventions.

**Lesson:** An AI assistant is useful for learning and speeding things up, but I need to understand and verify every command. I also must never paste secrets or private credentials into prompts.
