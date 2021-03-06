defmodule Cadet.Course do
  @moduledoc """
  Course context contains domain logic for Course administration
  management such as discussion groups, materials, and announcements
  """
  use Cadet, :context

  alias Cadet.Accounts.User
  alias Cadet.Course.Announcement
  alias Cadet.Course.Point
  alias Cadet.Course.Group
  alias Cadet.Course.Material
  alias Cadet.Course.Upload

  @doc """
  Create announcement entity using specified user as poster
  """
  def create_announcement(poster = %User{}, attrs = %{}) do
    changeset =
      Announcement.changeset(%Announcement{}, attrs)
      |> put_assoc(:poster, poster)

    Repo.insert(changeset)
  end

  @doc """
  Edit Announcement with specified ID entity by specifying changes
  """
  def edit_announcement(id, changes = %{}) do
    announcement = Repo.get(Announcement, id)

    if announcement == nil do
      {:error, :not_found}
    else
      changeset = Announcement.changeset(announcement, changes)
      Repo.update(changeset)
    end
  end

  @doc """
  Get Announcement with specified ID
  """
  def get_announcement(id) do
    Repo.get(Announcement, id)
    |> Repo.preload(:poster)
  end

  @doc """
  Delete Announcement with specified ID
  """
  def delete_announcement(id) do
    announcement = Repo.get(Announcement, id)

    if announcement == nil do
      {:error, :not_found}
    else
      Repo.delete(announcement)
    end
  end

  @doc """
  Give manual XP to another user
  """
  def give_manual_xp(given_by = %User{}, given_to = %User{}, attr = %{}) do
    if given_by.role == :student do
      {:error, :insufficient_privileges}
    else
      changeset =
        Point.changeset(%Point{}, attr)
        |> put_assoc(:given_by, given_by)
        |> put_assoc(:given_to, given_to)

      Repo.insert(changeset)
    end
  end

  @doc """
  Retract previously given manual XP entry another user
  """
  def delete_manual_xp(user = %User{}, id) do
    point = Repo.get(Point, id)

    cond do
      point == nil -> {:error, :not_found}
      !(user.role == :admin || point.given_by_id == user.id) -> {:error, :insufficient_privileges}
      true -> Repo.delete(point)
    end
  end

  @doc """
  Reassign a student to a discussion group.
  This will un-assign student from the current discussion group
  """
  def assign_group(leader = %User{}, student = %User{}) do
    cond do
      leader.role == :student ->
        {:error, :invalid}

      student.role != :student ->
        {:error, :invalid}

      true ->
        Repo.transaction(fn ->
          {:ok, _} = unassign_group(student)

          Group.changeset(%Group{}, %{})
          |> put_assoc(:leader, leader)
          |> put_assoc(:student, student)
          |> Repo.insert!()
        end)
    end
  end

  @doc """
  Remove existing student from discussion group, no-op if a student
  is unassigned
  """
  def unassign_group(student = %User{}) do
    existing_group = Repo.get_by(Group, student_id: student.id)

    if existing_group == nil do
      {:ok, nil}
    else
      Repo.delete(existing_group)
    end
  end

  @doc """
  Get list of students under staff discussion group
  """
  def list_students_by_leader(staff = %User{}) do
    import Cadet.Course.Query, only: [group_members: 1]

    Repo.all(group_members(staff))
    |> Repo.preload([:student])
  end

  @doc """
  Create a new folder to put material files in
  """
  def create_material_folder(uploader = %User{}, attrs = %{}) do
    create_material_folder(nil, uploader, attrs)
  end

  @doc """
  Create a new folder to put material files in
  """
  def create_material_folder(parent, uploader = %User{}, attrs = %{}) do
    changeset =
      Material.folder_changeset(%Material{}, attrs)
      |> put_assoc(:uploader, uploader)

    case parent do
      %Material{} ->
        Repo.insert(put_assoc(changeset, :parent, parent))

      _ ->
        Repo.insert(changeset)
    end
  end

  @doc """
  Upload a material file to designated folder
  """
  def upload_material_file(folder = %Material{}, uploader = %User{}, attr = %{}) do
    changeset =
      Material.changeset(%Material{}, attr)
      |> put_assoc(:uploader, uploader)
      |> put_assoc(:parent, folder)

    Repo.insert(changeset)
  end

  @doc """
  Delete a material file/directory. A directory tree
  is deleted recursively
  """
  def delete_material(id) when is_binary(id) or is_number(id) do
    material = Repo.get(Material, id)
    delete_material(material)
  end

  def delete_material(material = %Material{}) do
    cond do
      material == nil ->
        {:error, :not_found}

      material.file != nil ->
        Upload.delete({material.file, material})
        Repo.delete(material)

      true ->
        Repo.delete(material)
    end
  end

  @doc """
  List material folder content 
  """
  def list_material_folders(folder = %Material{}) do
    import Cadet.Course.Query, only: [material_folder_files: 1]
    Repo.all(material_folder_files(folder.id))
  end
end
