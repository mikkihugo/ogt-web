import { Heading, Container, Input, Textarea, Button, Label, Switch } from "@medusajs/ui"
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query"
import { useState, useEffect } from "react"
import { useParams, useNavigate } from "react-router-dom"

const PostDetail = () => {
    const { id } = useParams()
    const navigate = useNavigate()
    const queryClient = useQueryClient()
    const isNew = id === "create"

    const [formData, setFormData] = useState({
        title: "",
        slug: "",
        excerpt: "",
        content: "",
        category: "wellness",
        published_at: new Date().toISOString().slice(0, 16), // datetime-local format
        channel_config: { ids: [] as string[] }
    })

    // Fetch Post if editing
    const { data: postData, isLoading } = useQuery({
        queryKey: ["blog-post", id],
        queryFn: async () => {
            const res = await fetch(`/admin/blog/${id}`)
            return await res.json()
        },
        enabled: !isNew
    })

    // Fetch Sales Channels for selector
    const { data: channelsData } = useQuery({
        queryKey: ["sales-channels"],
        queryFn: async () => {
            // Standard Admin API for sales channels
            const res = await fetch("/admin/sales-channels")
            return await res.json()
        }
    })

    useEffect(() => {
        if (postData?.post) {
            const p = postData.post
            setFormData({
                title: p.title || "",
                slug: p.slug || "",
                excerpt: p.excerpt || "",
                content: p.content || "",
                category: p.category || "wellness",
                published_at: p.published_at ? new Date(p.published_at).toISOString().slice(0, 16) : "",
                channel_config: p.channel_config || { ids: [] }
            })
        }
    }, [postData])

    const mutation = useMutation({
        mutationFn: async (data: any) => {
            const url = isNew ? "/admin/blog" : `/admin/blog/${id}`
            const method = isNew ? "POST" : "POST" // Update is also POST in our route implementation

            // Format date back to ISO
            const payload = {
                ...data,
                published_at: new Date(data.published_at).toISOString()
            }

            const res = await fetch(url, {
                method,
                headers: { "Content-Type": "application/json" },
                body: JSON.stringify(payload)
            })
            if (!res.ok) throw new Error("Failed to save")
            return await res.json()
        },
        onSuccess: () => {
            queryClient.invalidateQueries({ queryKey: ["blog-posts"] })
            navigate("/blog")
        }
    })

    const handleSubmit = (e: React.FormEvent) => {
        e.preventDefault()
        mutation.mutate(formData)
    }

    const toggleChannel = (channelId: string) => {
        const currentIds = formData.channel_config.ids || []
        const newIds = currentIds.includes(channelId)
            ? currentIds.filter(id => id !== channelId)
            : [...currentIds, channelId]

        setFormData({
            ...formData,
            channel_config: { ...formData.channel_config, ids: newIds }
        })
    }

    if (isLoading) return <div>Loading...</div>

    return (
        <Container className="p-8 max-w-4xl mx-auto">
            <Heading level="h1" className="mb-6">{isNew ? "Create Post" : "Edit Post"}</Heading>

            <form onSubmit={handleSubmit} className="flex flex-col gap-6">
                <div className="flex flex-col gap-2">
                    <Label>Title</Label>
                    <Input
                        value={formData.title}
                        onChange={(e) => setFormData({ ...formData, title: e.target.value })}
                        required
                    />
                </div>

                <div className="grid grid-cols-2 gap-4">
                    <div className="flex flex-col gap-2">
                        <Label>Slug</Label>
                        <Input
                            value={formData.slug}
                            onChange={(e) => setFormData({ ...formData, slug: e.target.value })}
                            required
                        />
                    </div>
                    <div className="flex flex-col gap-2">
                        <Label>Category</Label>
                        <Input
                            value={formData.category}
                            onChange={(e) => setFormData({ ...formData, category: e.target.value })}
                        />
                    </div>
                </div>

                <div className="flex flex-col gap-2">
                    <Label>Excerpt</Label>
                    <Textarea
                        value={formData.excerpt}
                        onChange={(e) => setFormData({ ...formData, excerpt: e.target.value })}
                        rows={2}
                    />
                </div>

                <div className="flex flex-col gap-2">
                    <Label>Content (Markdown)</Label>
                    <Textarea
                        value={formData.content}
                        onChange={(e) => setFormData({ ...formData, content: e.target.value })} // Typo fixed from excerpt to content
                        rows={10}
                        className="font-mono"
                    />
                </div>

                <div className="flex flex-col gap-2">
                    <Label>Publish Date</Label>
                    <Input
                        type="datetime-local"
                        value={formData.published_at}
                        onChange={(e) => setFormData({ ...formData, published_at: e.target.value })}
                    />
                </div>

                <div className="flex flex-col gap-3 border p-4 rounded-md">
                    <Label className="font-semibold">Sales Channels (Visibility)</Label>
                    <div className="grid grid-cols-2 gap-2">
                        {channelsData?.sales_channels?.map((channel: any) => (
                            <div key={channel.id} className="flex items-center gap-2">
                                <Switch
                                    checked={formData.channel_config?.ids?.includes(channel.id)}
                                    onCheckedChange={() => toggleChannel(channel.id)}
                                />
                                <span className="text-sm">{channel.name}</span>
                            </div>
                        ))}
                    </div>
                </div>

                <div className="flex justify-end gap-2 mt-4">
                    <Button variant="secondary" onClick={() => navigate("/blog")} type="button">
                        Cancel
                    </Button>
                    <Button type="submit" isLoading={mutation.isPending}>
                        Save Post
                    </Button>
                </div>
            </form>
        </Container>
    )
}

export default PostDetail
