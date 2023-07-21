module test

using SimpleDirectMediaLayer
using SimpleDirectMediaLayer.LibSDL2
import Base.sin
import LinearAlgebra.norm
using Random
using Printf
using Base.Threads

# Structure for sine wave with frequency, phase, volume and panning
mutable struct SineWave
    frequency::Float64
    phase::Float64
    volume::Float64
    panning::Float64
end

# Create an array to hold the sine waves
sine_waves::Vector{SineWave} = SineWave[]

function add_sine_wave(frequency::Float64, phase::Float64, volume::Float64, panning::Float64)::Nothing
    push!(sine_waves, SineWave(frequency, phase, volume, panning))
end

function delete_sine_wave(index::Int)::Nothing
    if index > length(sine_waves) || index < 1
        println("Invalid index.")
    else
        deleteat!(sine_waves, index)
    end
end

function update_sine_wave(index::Int, frequency::Float64, phase::Float64, volume::Float64, panning::Float64)::Nothing
    if index > length(sine_waves) || index < 1
        println("Invalid index.")
    else
        wave = sine_waves[index]
        wave.frequency = frequency
        wave.phase = phase
        wave.volume = volume
        wave.panning = panning # range -1 (left) to 1 (right)
    end
end

let
    sample::Vector{Int16} = Float32[0, 0]
    function push_audio(audio_device::CInt, frame_size::UInt32)
        sample_size::Int = sizeof(Float32) * 2 # 2 for stereo

        for i in 1:frame_size
            sample_left::Int16 = Float32(0)
            sample_right::Int16 = Float32(0)

            # Calculate the output for each sine wave
            for wave::SineWave in sine_waves
                output::Float32 = wave.volume * sin(wave.frequency * i / audio_spec.freq + wave.phase)

                # Add the output to the left and right channels, taking panning into account
                sample_left += output * (1 - wave.panning)
                sample_right += output * wave.panning

                # Update the phase for the next cycle
                wave.phase += wave.frequency / audio_spec.freq
            end

            # Update the sample vector
            sample[1] = sample_left
            sample[2] = sample_right

            SDL_QueueAudio(audio_device, sample, sample_size)
        end
    end
end

function main()::Nothing
    SDL_Init(SDL_INIT_AUDIO)

    sample_rate::CInt = 480000
    buffer_size::UInt32 = 1024

    audio_spec = SDL_AudioSpec(sample_rate, AUDIO_F32SYS, 2, 0, buffer_size, 0, 0, C_NULL, C_NULL)
    audio_device::Cint = SDL_OpenAudioDevice(C_NULL, 0, Ref(audio_spec), C_NULL, 0)

    sample_size::Int = sizeof(Float32) * 2 # 2 for stereo

    # Preallocate the sample

    # Thread for continuously producing and playing audio
    @thread begin
        while true
            # Wait if the queue is full
            #Note this in practice means that the total latency can be up to 2x buffer size
            while SDL_GetQueuedAudioSize(audio_device) > audio_spec.samples * sample_size
                sleep(buffer_size / sample_rate / 20) # Avoid busy waiting
            end
            push_audio(audio_device, audio_spec.samples)
        end
    end

    # Thread for reading user input
    @thread begin
        while true
            print("Enter command: ")
            command::String = readline()
            try
                eval(Meta.parse(command))
            catch err
                println("Invalid command.")
            end
        end
    end
end

main()
end
