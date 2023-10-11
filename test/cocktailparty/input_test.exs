defmodule Cocktailparty.InputTest do
  use Cocktailparty.DataCase

  alias Cocktailparty.Input

  describe "redisinstances" do
    alias Cocktailparty.Input.RedisInstances

    import Cocktailparty.InputFixtures

    @invalid_attrs %{enabled: nil, name: nil, uri: nil}

    test "list_redisinstances/0 returns all redisinstances" do
      redis_instances = redis_instances_fixture()
      assert Input.list_redisinstances() == [redis_instances]
    end

    test "get_redis_instances!/1 returns the redis_instances with given id" do
      redis_instances = redis_instances_fixture()
      assert Input.get_redis_instances!(redis_instances.id) == redis_instances
    end

    test "create_redis_instances/1 with valid data creates a redis_instances" do
      valid_attrs = %{enabled: true, name: "some name", uri: "some uri"}

      assert {:ok, %RedisInstances{} = redis_instances} = Input.create_redis_instances(valid_attrs)
      assert redis_instances.enabled == true
      assert redis_instances.name == "some name"
      assert redis_instances.uri == "some uri"
    end

    test "create_redis_instances/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Input.create_redis_instances(@invalid_attrs)
    end

    test "update_redis_instances/2 with valid data updates the redis_instances" do
      redis_instances = redis_instances_fixture()
      update_attrs = %{enabled: false, name: "some updated name", uri: "some updated uri"}

      assert {:ok, %RedisInstances{} = redis_instances} = Input.update_redis_instances(redis_instances, update_attrs)
      assert redis_instances.enabled == false
      assert redis_instances.name == "some updated name"
      assert redis_instances.uri == "some updated uri"
    end

    test "update_redis_instances/2 with invalid data returns error changeset" do
      redis_instances = redis_instances_fixture()
      assert {:error, %Ecto.Changeset{}} = Input.update_redis_instances(redis_instances, @invalid_attrs)
      assert redis_instances == Input.get_redis_instances!(redis_instances.id)
    end

    test "delete_redis_instances/1 deletes the redis_instances" do
      redis_instances = redis_instances_fixture()
      assert {:ok, %RedisInstances{}} = Input.delete_redis_instances(redis_instances)
      assert_raise Ecto.NoResultsError, fn -> Input.get_redis_instances!(redis_instances.id) end
    end

    test "change_redis_instances/1 returns a redis_instances changeset" do
      redis_instances = redis_instances_fixture()
      assert %Ecto.Changeset{} = Input.change_redis_instances(redis_instances)
    end
  end

  describe "redisinstances" do
    alias Cocktailparty.Input.RedisInstance

    import Cocktailparty.InputFixtures

    @invalid_attrs %{enabled: nil, name: nil, uri: nil}

    test "list_redisinstances/0 returns all redisinstances" do
      redis_instance = redis_instance_fixture()
      assert Input.list_redisinstances() == [redis_instance]
    end

    test "get_redis_instance!/1 returns the redis_instance with given id" do
      redis_instance = redis_instance_fixture()
      assert Input.get_redis_instance!(redis_instance.id) == redis_instance
    end

    test "create_redis_instance/1 with valid data creates a redis_instance" do
      valid_attrs = %{enabled: true, name: "some name", uri: "some uri"}

      assert {:ok, %RedisInstance{} = redis_instance} = Input.create_redis_instance(valid_attrs)
      assert redis_instance.enabled == true
      assert redis_instance.name == "some name"
      assert redis_instance.uri == "some uri"
    end

    test "create_redis_instance/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Input.create_redis_instance(@invalid_attrs)
    end

    test "update_redis_instance/2 with valid data updates the redis_instance" do
      redis_instance = redis_instance_fixture()
      update_attrs = %{enabled: false, name: "some updated name", uri: "some updated uri"}

      assert {:ok, %RedisInstance{} = redis_instance} = Input.update_redis_instance(redis_instance, update_attrs)
      assert redis_instance.enabled == false
      assert redis_instance.name == "some updated name"
      assert redis_instance.uri == "some updated uri"
    end

    test "update_redis_instance/2 with invalid data returns error changeset" do
      redis_instance = redis_instance_fixture()
      assert {:error, %Ecto.Changeset{}} = Input.update_redis_instance(redis_instance, @invalid_attrs)
      assert redis_instance == Input.get_redis_instance!(redis_instance.id)
    end

    test "delete_redis_instance/1 deletes the redis_instance" do
      redis_instance = redis_instance_fixture()
      assert {:ok, %RedisInstance{}} = Input.delete_redis_instance(redis_instance)
      assert_raise Ecto.NoResultsError, fn -> Input.get_redis_instance!(redis_instance.id) end
    end

    test "change_redis_instance/1 returns a redis_instance changeset" do
      redis_instance = redis_instance_fixture()
      assert %Ecto.Changeset{} = Input.change_redis_instance(redis_instance)
    end
  end
end
