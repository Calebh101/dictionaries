"""Console script for dictionaries_addons_framework."""

import typer
from rich.console import Console

app = typer.Typer()
console = Console()

@app.command()
def main():
    """Console script for dictionaries_addons_framework."""


if __name__ == "__main__":
    app()
