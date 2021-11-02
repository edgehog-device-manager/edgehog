defmodule Edgehog.Release do
  @app :edgehog

  def migrate do
    load_app()

    for repo <- repos() do
      {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :up, all: true))
    end
  end

  def seed do
    load_app()

    for repo <- repos() do
      {:ok, _, _} = Ecto.Migrator.with_repo(repo, &eval_seed_file/1)
    end
  end

  defp eval_seed_file(_repo) do
    priv_dir = "#{:code.priv_dir(@app)}"
    seeds_file = Path.join([priv_dir, "repo", "seeds.exs"])

    {:ok, _} = Code.eval_file(seeds_file)

    :ok
  end

  def rollback(repo, version) do
    load_app()

    {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :down, to: version))
  end

  defp repos do
    Application.fetch_env!(@app, :ecto_repos)
  end

  defp load_app do
    Application.load(@app)
  end
end
