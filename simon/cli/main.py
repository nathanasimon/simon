"""CLI entry point for simon."""

import typer

app = typer.Typer(
    name="simon",
    help="Simon — context injection and session memory for Claude Code",
    no_args_is_help=True,
)


def main():
    from simon.cli.hooks_cmd import app as hooks_app
    from simon.cli.retrieve_cmd import app as retrieve_app
    from simon.cli.record_cmd import app as record_app
    from simon.cli.context_cmd import app as context_app
    from simon.cli.skill_cmd import app as skill_app
    from simon.cli.worker_cmd import app as worker_app

    app.add_typer(hooks_app, name="hooks", help="Install/manage Claude Code hooks")
    app.add_typer(retrieve_app, name="retrieve", help="Retrieve context")
    app.add_typer(record_app, name="record", help="Record conversations")
    app.add_typer(context_app, name="context", help="Query and debug context system")
    app.add_typer(skill_app, name="skill", help="Manage Claude Code skills")
    app.add_typer(worker_app, name="worker", help="Background worker management")

    app()


if __name__ == "__main__":
    main()
