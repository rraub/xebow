defmodule XebowTest do
  use ExUnit.Case

  alias RGBMatrix.Animation

  # This must be added as part of `setup` so the pid belongs to the test process
  defp add_config_fn(_context) do
    pid = self()

    config_fn = fn config ->
      send(pid, {:config, config})
      :ok
    end

    [config_fn: config_fn]
  end

  defp add_mock_animations(_context) do
    mock_animations = [
      Type1,
      Type2,
      Type3
    ]

    Enum.each(mock_animations, fn module_name ->
      Module.create(module_name, mock_animation_module(module_name), __ENV__)
    end)

    [mock_animations: mock_animations]
  end

  defp add_single_animation(_context), do: [single_animation: [Type1]]

  defp add_single_schema(_context) do
    schema = [
      test_field: %RGBMatrix.Animation.Config.FieldType.Option{
        options: [:a, :b],
        default: :a,
        doc: []
      }
    ]

    [single_schema: schema]
  end

  defp get_animation_module_from_config({%config_module{}, _schema}) do
    config_module
    |> Module.split()
    |> List.delete("Config")
    |> Module.concat()
  end

  defp mock_animation_module(Type1) do
    quote do
      use Animation

      field :test_field, :option,
        options: ~w(a b)a,
        default: :a

      @impl true
      def new(_leds, _config), do: nil

      @impl true
      def render(_state, _config), do: {1000, %{}, nil}
    end
  end

  defp mock_animation_module(_) do
    quote do
      use Animation

      @impl true
      def new(_leds, _config), do: nil

      @impl true
      def render(_state, _config), do: {1000, %{}, nil}
    end
  end

  defp monitor_xebow_process(_context) do
    Process.monitor(Xebow)
    :ok
  end

  defmacrop assert_receive_down do
    quote do
      assert_receive {:DOWN, _ref, :process, _object, _reason}
    end
  end

  defmacrop refute_receive_down do
    quote do
      refute_receive {:DOWN, _ref, :process, _object, _reason}
    end
  end

  setup_all [
    :add_mock_animations,
    :add_single_animation,
    :add_single_schema
  ]

  setup :monitor_xebow_process

  test "has layout" do
    assert %Layout{} = Xebow.layout()
  end

  describe "can get and set active animation types" do
    test "using a list of animation modules", %{
      mock_animations: mock_animations
    } do
      assert Xebow.set_active_animation_types(mock_animations) == :ok
      assert Xebow.get_active_animation_types() == mock_animations

      refute_receive_down()
    end

    test "using an empty list" do
      assert Xebow.set_active_animation_types([]) == :ok
      assert Xebow.get_active_animation_types() == []

      refute_receive_down()
    end
  end

  describe "get_animation_config/0" do
    test "returns the current animation's config and schema", %{
      single_animation: single_animation,
      single_schema: single_schema
    } do
      Xebow.set_active_animation_types(single_animation)
      [animation_module] = single_animation

      assert {%config_module{}, ^single_schema} = Xebow.get_animation_config()

      split_config_module = Module.split(config_module)

      assert {"Config", split_animation_module} = List.pop_at(split_config_module, -1)
      assert ^animation_module = Module.concat(split_animation_module)

      refute_receive_down()
    end

    test "returns nil when no animations active" do
      Xebow.set_active_animation_types([])

      assert Xebow.get_animation_config() == nil

      refute_receive_down()
    end
  end

  setup %{mock_animations: mock_animations} do
    Xebow.set_active_animation_types(mock_animations)
  end

  describe "next_animation/0" do
    test "cycles through animations without crashing" do
      assert Xebow.next_animation() == :ok
      refute_receive_down()
    end

    test "can cycle through the whole list", %{
      mock_animations: mock_animations
    } do
      assert [] =
               Enum.reduce(mock_animations, mock_animations, fn _, acc ->
                 Xebow.next_animation()
                 animation_module = get_animation_module_from_config(Xebow.get_animation_config())

                 assert Enum.member?(acc, animation_module)

                 List.delete(acc, animation_module)
               end)

      refute_receive_down()
    end
  end

  describe "previous_animation/0" do
    test "cycles through animations without crashing" do
      assert Xebow.previous_animation() == :ok
    end

    test "can cycle through the whole list", %{
      mock_animations: mock_animations
    } do
      assert [] =
               Enum.reduce(mock_animations, mock_animations, fn _, acc ->
                 Xebow.previous_animation()
                 animation_module = get_animation_module_from_config(Xebow.get_animation_config())

                 assert Enum.member?(acc, animation_module)

                 List.delete(acc, animation_module)
               end)

      refute_receive_down()
    end
  end

  describe "update_animation_config/1" do
    test "updates the current animation", %{
      single_animation: single_animation
    } do
      Xebow.set_active_animation_types(single_animation)
      single_config = Xebow.get_animation_config()
      update_params = %{test_field: :b}

      assert Xebow.update_animation_config(update_params) == :ok
      refute Xebow.get_animation_config() == single_config

      {config, _schema} = Xebow.get_animation_config()

      assert config.test_field == :b

      refute_receive_down()
    end
  end

  setup :add_config_fn

  describe "register_configurable/1" do
    @tag capture_log: true
    test "crashes the engine if a non-function is registered" do
      fake_config_fn = "KITTY!"

      assert Xebow.register_configurable(fake_config_fn) == {:ok, fake_config_fn}

      Xebow.next_animation()

      assert_receive_down()
    end

    test "registers configurables", %{
      config_fn: config_fn
    } do
      assert Xebow.register_configurable(config_fn) == {:ok, config_fn}

      Xebow.next_animation()
      config = Xebow.get_animation_config()

      assert_receive {:config, ^config}

      refute_receive_down()
    end
  end

  describe "unregister_configurable/1" do
    @tag capture_log: true
    test "ignores invalid input" do
      Process.monitor(Xebow)

      assert Xebow.unregister_configurable("DOGGY!") == :ok

      refute_receive_down()
    end

    test "unregisters configurables", %{
      config_fn: config_fn
    } do
      Xebow.register_configurable(config_fn)

      assert Xebow.unregister_configurable(config_fn) == :ok

      Xebow.previous_animation()
      config = Xebow.get_animation_config()

      refute_receive {:config, ^config}

      refute_receive_down()
    end
  end

  describe "configurable functions" do
    test "are called when switching animations", %{
      config_fn: config_fn
    } do
      Xebow.register_configurable(config_fn)

      Xebow.next_animation()
      config = Xebow.get_animation_config()
      assert_receive {:config, ^config}

      Xebow.previous_animation()
      config = Xebow.get_animation_config()
      assert_receive {:config, ^config}

      refute_receive_down()
    end

    test "return :unregister to unregister" do
      pid = self()
      message = {:config, "unregister"}

      config_fn = fn _config ->
        send(pid, message)
        :unregister
      end

      assert Xebow.register_configurable(config_fn) == {:ok, config_fn}

      Xebow.next_animation()
      assert_receive ^message

      Xebow.next_animation()
      refute_receive ^message

      refute_receive_down()
    end
  end
end
