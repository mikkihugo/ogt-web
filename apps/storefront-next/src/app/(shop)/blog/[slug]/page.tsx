import Link from "next/link"
import { notFound } from "next/navigation"

interface Post {
    id: string
    title: string
    slug: string
    content: string
    published_at: string
}

async function getPost(slug: string) {
    const backendUrl = process.env.NEXT_PUBLIC_MEDUSA_BACKEND_URL || "http://localhost:9000"
    try {
        // Fetch all posts (cached) and filter, since backend API doesn't support slug filter yet
        const res = await fetch(`${backendUrl}/store/blog`, {
            next: { revalidate: 3600 }
        })

        if (!res.ok) return null

        const data = await res.json()
        const posts = data.posts || []

        return posts.find((p: Post) => p.slug === slug)
    } catch (err) {
        console.error("Error fetching post:", err)
        return null
    }
}

export default async function BlogPost({ params }: { params: Promise<{ slug: string }> }) {
    const slug = (await params).slug
    const post = await getPost(slug)

    if (!post) {
        notFound()
    }

    return (
        <div className="container mx-auto px-4 py-12 max-w-3xl">
            <article className="prose lg:prose-xl mx-auto">
                <h1>{post.title}</h1>
                {post.published_at && (
                    <p className="text-gray-500 text-sm mb-8">
                        {new Date(post.published_at).toLocaleDateString()}
                    </p>
                )}

                {/* Simple rendering for now - assuming plain text or simple HTML */}
                <div className="whitespace-pre-wrap">{post.content}</div>
            </article>

            <div className="mt-12 border-t pt-8">
                <Link href="/blog" className="text-blue-600 hover:underline">&larr; Back to Blog</Link>
            </div>
        </div>
    )
}
